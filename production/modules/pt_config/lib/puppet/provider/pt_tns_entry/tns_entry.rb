# ***************************************************************
#  This software and related documentation are provided under a
#  license agreement containing restrictions on use and
#  disclosure and are protected by intellectual property
#  laws. Except as expressly permitted in your license agreement
#  or allowed by law, you may not use, copy, reproduce,
#  translate, broadcast, modify, license, transmit, distribute,
#  exhibit, perform, publish or display any part, in any form or
#  by any means. Reverse engineering, disassembly, or
#  decompilation of this software, unless required by law for
#  interoperability, is prohibited.
#  The information contained herein is subject to change without
#  notice and is not warranted to be error-free. If you find any
#  errors, please report them to us in writing.
#
#  Copyright (C) 1988, 2017, Oracle and/or its affiliates.
#  All Rights Reserved.
# ***************************************************************

Puppet::Type.type(:pt_tns_entry).provide :tns_entry do
    mk_resource_methods

    def initialize(value={})
      super(value)
      Puppet.debug("Provider Initialization")
      @property_flush = {}
      @tns_entry_str = '(^(?i)(?:([\w]+.*?\s*)=[\n\s]*)(?:.*?[(](?i)DESCRIPTION\s*=[\n\s]*)(?:.*?[(]?.*[)]?)(?:[\n\s]*[(](?:(?:ADDRESS_LIST\s*=[\n\s\(]*)?(ADDRESS\s*=[\n\s]*[(](PROTOCOL\s*=[\n\s]*(?:TCP|IPC|SPX|NMP|BEQ|SDP))[\n\s]*[)][\n\s]*[(](HOST\s*=[\n\s]*(?:[\w.-]+))[\n\s]*[)][\n\s]*[(](PORT\s*=[\n\s]*(?:[\d]+))[\n\s]*[)][\n\s]*[)][\n\s]*)(?:[)])?)[\n\s]*[(](?:CONNECT_DATA\s*=[\n\s]*([(](?:SERVER|SERVICE_NAME|SID)\s*=[\n\s]*(?:[\w.]+)[\n\s]*[)])[\n\s]*([(](?:SERVER|SERVICE_NAME|SID)\s*=[\n\s]*(?:[\w.]+)[\n\s]*[)])?[\n\s]*([(](?:SERVER|SERVICE_NAME|SID)\s*=[\n\s]*(?:[\w.]+)[\n\s]*[)])?[\n\s]*[)][\n\s]*)[)])+)'
    end

    def db_host=(value)
      @property_flush[:db_host] = value
    end

    def db_port=(value)
      @property_flush[:db_port] = value
    end

    def db_protocol=(value)
      @property_flush[:db_protocol] = value
    end

    def db_service_name=(value)
      @property_flush[:db_service_name] = value
    end

    def exists?
      db_name = resource[:db_name]
      Puppet.debug("Exists called for DB name: #{db_name}")

      if ! @property_hash[:ensure].nil?
        return @property_hash[:ensure] == :present
      end

      db_name_exists = check_dbname_exists?(db_name)
      if db_name_exists == true
        @property_hash[:ensure] = :present
        Puppet.debug("Resource exists")
        true
      else
        @property_hash[:ensure] = :absent
        Puppet.debug("Resource does not exists")
        false
      end
    end

    def create
      db_name = resource[:db_name]
      Puppet.debug("Create called for DB name: #{db_name}")

      # make sure the db_host is given
      if resource[:db_host].nil?
        raise ArgumentError, "Oracle database host needs to be " +
          "specified to create TNS entry."
      end

      # create the TNS entry
      tns_file_name = resource[:tns_file_name]

      # make sure the tns file directory exists
      tns_dir_name = File.dirname(tns_file_name)
      if File.exists?(tns_dir_name) == false
        FileUtils.mkpath(tns_dir_name)
      end

      # create tns file if it doesn't exists
      if File.file?(tns_file_name) == false
        File.open(tns_file_name, "w").close()
      end

      db_service_name = resource[:db_service_name]
      rac_database = resource[:db_is_rac]
      begin
        open(tns_file_name,  'a') do |target|
          target.puts ""
          target.puts "#{db_name} ="
          target.puts "   (DESCRIPTION ="
          if rac_database == true
            target.puts "     (CONNECT_TIMEOUT=30)(RETRY_COUNT=5)"
          end
          target.puts "       (ADDRESS_LIST ="
          target.puts "           (ADDRESS = " +
                      "(PROTOCOL = #{resource[:db_protocol].to_s})" +
                      "(HOST = #{resource[:db_host]})" +
                      "(PORT = #{resource[:db_port]}))"
          target.puts "       )"
          target.puts "       (CONNECT_DATA ="
          target.puts "           (SERVER = DEDICATED)"
          target.puts "           (SERVICE_NAME = #{db_service_name})"
          target.puts "       )"
          target.puts "    )"
        end
      rescue
        raise Puppet::Error, "Unable to create TNS entry for DB name " +
                             "#{db_name}"
      end
      if Facter.value(:osfamily) != 'windows'
        # change the permissions of the tns names file
        tns_names_dir_stat = File.stat(tns_dir_name)
        File.chmod(0755, tns_file_name)
        FileUtils.chown(tns_names_dir_stat.uid, tns_names_dir_stat.gid, tns_file_name)
      end

      @property_hash[:ensure] = :present
      @property_flush.clear
    end

    def destroy
      db_name = resource[:db_name]
      Puppet.debug("Destroy called for DB name: #{db_name}")

      # remove the TNS entry
      tns_file_name = resource[:tns_file_name]

      # validate to make sure the tns file exists
      unless File.file?(tns_file_name)
       raise ArgumentError, "TNS file #{tns_file_name} does not exists"
      end

      tns_entry_reg =  Regexp.new @tns_entry_str

      content = File.read(tns_file_name)
      content.scan(tns_entry_reg) do |match|
        if match[0].include?(db_name)
          Puppet.debug("Matching DB entry found in the TNS file : #{match[0]}")
          file_content_mod = File.read(tns_file_name)
          file_content_mod.gsub!(match[0], '')
          file_content_mod.delete!("\n")
          Puppet.debug("Modified string : #{file_content_mod}")
          File.open(tns_file_name, "w") { |file| file << file_content_mod }
        end
      end
      # remove the file if the size is 0
      if File.size(tns_file_name) == 0
        FileUtils.remove_file(tns_file_name, :force => true)
      end
      @property_hash[:ensure] = :absent
      @property_flush.clear
    end

    def flush
      db_name = resource[:db_name]
      Puppet.debug("Flush called for DB name: #{db_name}")

      if @property_flush.size == 0
        Puppet.debug("Nothing to flush")
        return
      end
      # modify the TNS entry
      tns_file_name = resource[:tns_file_name]
      tns_entry_reg =  Regexp.new @tns_entry_str

      content = File.read(tns_file_name)
      content.scan(tns_entry_reg) do |match|
        if match[0].include?(db_name)

          match_element = match[0].match(tns_entry_reg)

          # make a copy of the matched tns entry
          tns_entry_mod = match[0].clone
          Puppet.debug("Modified string start : #{tns_entry_mod}")

          match_array = match_element.captures
          Puppet.debug("Matching DB entry found in the TNS file : " +
                       " Number of groups : #{match_array.size}" +
                       "#{match_array.inspect}")
          # get the protocol group
          db_protocol = @property_flush[:db_protocol].to_s
          if db_protocol.nil? == false
            Puppet.debug("Updating DB protocol with #{db_protocol}")
            protocol_group = match_array[3]
            Puppet.debug("Protocol group: #{protocol_group}")
            tns_entry_mod[protocol_group] = "PROTOCOL = #{db_protocol}"
            Puppet.debug("Modified string after PROTOCOL : #{tns_entry_mod}")
          end

          # get the host group
          db_host = @property_flush[:db_host]
          if db_host.nil? == false
            Puppet.debug("Updating DB host with #{db_host}")
            host_group = match_array[4]
            Puppet.debug("Host group: #{host_group}")
            tns_entry_mod[host_group] = "HOST = #{db_host}"
            Puppet.debug("Modified string after HOST : #{tns_entry_mod}")
          end

          # get the port group
          db_port = @property_flush[:db_port]
          if db_port.nil? == false
            Puppet.debug("Updating DB port with #{db_port}")
            port_group = match_array[5]
            Puppet.debug("Port group: #{port_group}")
            tns_entry_mod[port_group] = "PORT = #{db_port}"
            Puppet.debug("Modified string after PORT : #{tns_entry_mod}")
          end

          # for updating SID or SERVICE_NAME, we need to indentify
          # the current connection data elements. Its likely some of
          # these settings are not specified and even if they are specified,
          # they may be in different order. We will have to account
          # for that and update the connection data elements accordingly
          conn_data_group1 = match_array[6]
          Puppet.debug("Conn data group1: #{conn_data_group1}")
          conn_data_group2 = match_array[7]
          Puppet.debug("Conn data group1: #{conn_data_group2}")
          conn_data_group3 = match_array[8]
          Puppet.debug("Conn data group1: #{conn_data_group3}")

          conn_data_hash = {}
          sid_key = 'SID'
          server_key = 'SERVER'
          service_name_key = 'SERVICE_NAME'

          if conn_data_group1.include?(server_key)
            conn_data_hash[server_key] = conn_data_group1
          elsif conn_data_group1.include?(sid_key)
            conn_data_hash[sid_key] = conn_data_group1
          elsif conn_data_group1.include?(service_name_key)
            conn_data_hash[service_name_key] = conn_data_group1
          end

          if conn_data_group2.nil? == false
            if conn_data_group2.include?(server_key)
              conn_data_hash[server_key] = conn_data_group2
            elsif conn_data_group2.include?(sid_key)
              conn_data_hash[sid_key] = conn_data_group2
            elsif conn_data_group2.include?(service_name_key)
              conn_data_hash[service_name_key] = conn_data_group2
            end
          end

          if conn_data_group3.nil? == false
            if conn_data_group3.include?(server_key)
              conn_data_hash[server_key] = conn_data_group3
            elsif conn_data_group3.include?(sid_key)
              conn_data_hash[sid_key] = conn_data_group3
            elsif conn_data_group3.include?(service_name_key)
              conn_data_hash[service_name_key] = conn_data_group3
            end
          end

          # get the service_name group
          db_service_name = @property_flush[:db_service_name]
          if db_service_name.nil? == false
            Puppet.debug("Updating DB service_name with #{db_service_name}")

            # check if the hash has service_name entry
            sn_new_entry  = "(SERVICE_NAME = #{db_service_name})"
            sn_hash_entry = conn_data_hash[service_name_key]
            if sn_hash_entry.nil?
              # check if hash SERVER entry
              server_hash_entry = conn_data_hash[server_key]
              if server_hash_entry.nil?
                # check if hash has SID entry
                sid_hash_entry = conn_data_hash[sid_key]
                if sid_hash_entry.nil?
                  # none of the entries are present in CONNECT_DATA
                  # add the SERVICE_NAME entry
                  sn_new_entry = "CONNECT_DATA =\n        #{sn_new_entry}"
                  Puppet.debug("Updated SERVICE_NAME: #{sn_new_entry}")
                  tns_entry_mod.gsub!('/CONNECT_DATA\s*=/', sn_new_entry)
                else
                  # append the SERVICE_NAME entry after the SID entry
                  sn_new_entry = "#{sid_hash_entry}\n           #{sn_new_entry}"
                  Puppet.debug("Updated SERVICE_NAME: #{sn_new_entry}")
                  tns_entry_mod[sid_hash_entry] = sn_new_entry
                end
              else
                # append the SERVICE_NAME entry after the SERVER entry
                sn_new_entry = "#{server_hash_entry}\n           #{sn_new_entry}"
                Puppet.debug("Updated SERVICE_NAME: #{sn_new_entry}")
                tns_entry_mod[server_hash_entry] = sn_new_entry
              end
            else
              Puppet.debug("Updated SERVICE_NAME: #{sn_new_entry}")
              tns_entry_mod[sn_hash_entry] = sn_new_entry
            end
          end

          # update the TNS entry in the file
          file_content_mod = File.read(tns_file_name)
          file_content_mod.gsub!(match[0], tns_entry_mod)
          Puppet.debug("Modified string : #{file_content_mod}")
          File.open(tns_file_name, "w") { |file| file << file_content_mod }
        end
      end
      @property_hash = resource.to_hash
      @property_flush.clear
    end

    def self.instances
      []
    end

    private

    def check_dbname_exists?(db_name)
      tns_file_name = resource[:tns_file_name]

      db_entry_re = Regexp.new db_name
      Puppet.debug("Checking if DB name #{db_name} exists")

      db_entry_exists = false
      if File.file?(tns_file_name) and File.readlines(tns_file_name).grep(db_entry_re).any?
        db_entry_exists = true
      end
      return db_entry_exists
    end
end
