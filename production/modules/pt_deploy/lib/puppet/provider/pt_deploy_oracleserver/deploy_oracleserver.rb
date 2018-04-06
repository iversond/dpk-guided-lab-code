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

require 'puppet/provider/deployarchive'
require 'fileutils'
require 'pt_deploy_utils/validations'
require 'pt_deploy_utils/database'
require 'etc'

Puppet::Type.type(:pt_deploy_oracleserver).provide :deploy_oracleserver,
                  :parent => Puppet::Provider::DeployArchive do
  include ::PtDeployUtils::Validations
  include ::PtDeployUtils::Database

  #if Facter.value(:osfamily) == 'RedHat'
   # commands :extract_cmd =>  'tar'
    #commands :unzip_cmd   =>  'unzip'
  #end
  #if Facter.value(:osfamily) == 'AIX'
   # commands :extract_cmd  =>  'gunzip'
  #end
  
  if Facter.value(:osfamily) == 'RedHat'
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end
  if Facter.value(:osfamily) == 'AIX'
    commands :extract_cmd  =>  'gunzip'
  end
  if Facter.value(:osfamily) == 'Solaris'
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end

  mk_resource_methods

  def flush
    oracle_home_dir = resource[:deploy_location]
    Puppet.debug("Flush called for oracle home: #{oracle_home_dir}")

    if resource[:ensure] == :absent
      Puppet.debug("Ensure is absent, nothing to flush")
      return
    end

    # update the listener info if changed
    listener_name = resource[:listener_name]
    listener_port = resource[:listener_port].to_s

    cur_listener_port = 1521
    cur_listener_name = 'listener'

    db_listener_file = File.join(oracle_home_dir, 'network', 'admin', 'listener.ora')
    listener_file_content = File.read(db_listener_file)
    listener_port_match_regex = Regexp.new('(^.*)(PORT)( = )([0-9]+)(\).*)')
    listener_port_match_found = listener_file_content.match(listener_port_match_regex)
    if listener_port_match_found.nil? == false
      cur_listener_port = listener_port_match_found[4]
      Puppet.debug("Current listener port is #{cur_listener_port}")
    end

    listener_name_match_regex = Regexp.new('^(.*listener)(\s*=)$')
    listener_name_match_found = listener_file_content.match(listener_name_match_regex)
    if listener_name_match_found.nil? == false
      cur_listener_name = listener_name_match_found[1]
      Puppet.debug("Current listener name is #{cur_listener_name}")
    end

    oracle_user = resource[:deploy_user]

    if cur_listener_port != listener_port || cur_listener_name != listener_name
      Puppet.debug("Updating listener file")
      stop_listener(oracle_home_dir, cur_listener_name, oracle_user)
      create_listener_file(db_listener_file, listener_name, listener_port)
      updated = true
    end
    # start the listener
    start_listener(oracle_home_dir, listener_name, oracle_user)
  end

  private

  def validate_parameters()
    super()
    if Facter.value(:osfamily) != 'windows'
      search_cmd = 'grep -i '
      search_string = 'LISTEN'
      null_suffix = ' >/dev/null'

      deploy_user = resource[:deploy_user]
      deploy_group = resource[:deploy_user_group]
      inventory_location = resource[:oracle_inventory_location]
      inventory_user = resource[:oracle_inventory_user]
      inventory_group = resource[:oracle_inventory_group]

      validate_oracle_inventory_permissions(inventory_location,
                                            inventory_user, inventory_group,
                                            deploy_user, deploy_group)
    else
      search_cmd ='find /I '
      search_string = 'LISTENING'
      null_suffix = ' >/NUL'
    end
    # validate to make sure the listner port is not in use
    listener_port = resource[:listener_port].to_s
    port_check_cmd = "netstat -an | #{search_cmd} \":#{listener_port}\s\" | #{search_cmd} \"TCP\" | #{search_cmd} \"#{search_string}\" #{null_suffix}"
    Puppet.debug("Port validation cmd: #{port_check_cmd}")
    system(port_check_cmd)
    if $? == 0
      error_msg = "Oracle server listener port #{listener_port} already in use"
      Puppet.debug(error_msg)
      raise Puppet::ExecutionFailure, "#{error_msg}"
    end
  end

  def post_create()
    # create the oracle inventory if needed
    inventory_location = resource[:oracle_inventory_location]
    inventory_user = resource[:oracle_inventory_user]
    inventory_group = resource[:oracle_inventory_group]
    inventory_location = checkcreate_oracle_inventory(inventory_location,
                                 inventory_user, inventory_group)

    # clone the oracle home
    oracle_home = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    deploy_group = resource[:deploy_user_group]
    clone_oracle_home(oracle_home, deploy_user, deploy_group,
                      inventory_location, 'server')

    # set up the listener
    listener_name = resource[:listener_name]
    listener_port = resource[:listener_port].to_s

    listener_file = File.join(oracle_home, 'network', 'admin', 'listener.ora')
    create_listener_file(listener_file, listener_name, listener_port)

    # Create default sqlnet.ora file if not already present
    if Facter.value(:osfamily) != 'windows'
      sqlnet_file = File.join(oracle_home, 'network', 'admin', 'samples', 'sqlnet.ora')
    else
      sqlnet_file = File.join(oracle_home, 'network', 'admin', 'sample', 'sqlnet.ora')
    end
    db_sqlnet_file = File.join(oracle_home, 'network', 'admin', 'sqlnet.ora')
    if File.exists?(db_sqlnet_file) == false
      Puppet.debug("SQLNET file #{db_sqlnet_file} does not exists, copying from samples")
      FileUtils.cp(sqlnet_file, db_sqlnet_file)
    else
      Puppet.debug("SQLNET file #{db_sqlnet_file} exists")
    end
    # add EXPIRE_TIMEOUT in the SQLNET file
    open(db_sqlnet_file, 'a') do |sqlnet|
        sqlnet.puts('SQLNET.EXPIRE_TIME = 6')
    end

    if Facter.value(:osfamily) != 'windows'
      user_uid = Etc.getpwnam(deploy_user).uid
      group_gid = Etc.getgrnam(deploy_group).gid

      oracle_admin_dir = File.join(oracle_home, 'network', 'admin')
      Puppet.debug("Changing ownership of #{oracle_admin_dir}")
      FileUtils.chown_R(user_uid, group_gid, oracle_admin_dir)

      # remove the semaphore if it exists
      FileUtils.remove_file(File.join('/var', 'tmp', '.oracle', "sEXTPROC#{listener_port}"),
                            :force => true)
    end

    # install oracle server patches if specified
    patch_list = resource[:patch_list]
    if ! patch_list.nil?
      patch_list = [patch_list] unless patch_list.is_a? Array
      patch_list.each do |patch|
        ods_patch_dir = Dir.mktmpdir(['odspatch', 'dir'], oracle_home)
        FileUtils.chmod(0755, ods_patch_dir)

        if Facter.value(:osfamily) == 'windows'
          Puppet.debug("Extracting Oracle Server patch on Windows platform")

          extract_zip_script = generate_windows_unzip_script(patch, ods_patch_dir)
          system("powershell -File #{extract_zip_script}")
          if $? == 0
            Puppet.debug("Extraction of Oracle Server patch #{patch} successful")
          else
            raise Puppet::ExecutionFailure, "Extraction of Oracle Server patch #{patch} failed"
          end
        else
          Puppet.debug("Extraction Oracle Server patch on Linux platform")
          if Facter.value(:osfamily) == 'AIX'
            system("cd #{ods_patch_dir} && gunzip -r #{patch} -c | tar xf -")
          else
            unzip_cmd('-d', ods_patch_dir, patch)
          end
          change_ownership(deploy_user, deploy_group, ods_patch_dir)
        end
        begin
          Puppet.debug("Installing Oracle Server patch #{patch}")
          ods_patch_num = Dir.entries(ods_patch_dir).reject {|f| File.directory?(f) || f.include?('.')}[0]
          Puppet.debug('Installing Oracle Server patch number ' + ods_patch_num)

          patch_dir = "#{ods_patch_dir}/#{ods_patch_num}"
          ods_patch_list = Dir.entries(patch_dir).reject {|f| File.directory?(f) || f.include?('.')}

          # check if ods_patch_list consists of a composite patch list
          composite_patch = true
          ods_patch_list.each do |ods_patch_item|
            is_patch_num = !!Integer(ods_patch_item) rescue false
            if is_patch_num == false
              composite_patch = false
              break
            end
          end
          if composite_patch == true
            Puppet.debug("Patch #{ods_patch_num} is a composite patch")
            ods_patch_list.each do |ods_patch_item|
              patch_apply_dir = "#{patch_dir}/#{ods_patch_item}"
              apply_patch(ods_patch_item, patch_apply_dir)
            end
          else
            apply_patch(ods_patch_num, patch_dir)
          end
        rescue Puppet::ExecutionFailure => e
          Puppet.debug("Oracle Server patch installation failed: #{e.message}")
          raise Puppet::Error, "Installation of Oracle Server patch #{patch} failed: #{e.message}"
        ensure
          FileUtils.remove_entry(ods_patch_dir)
        end
      end
    else
      Puppet.debug("No Oracle Server patches listed to install")
    end
    # start the listener
    begin
      start_listener(oracle_home, listener_name, deploy_user)
      if Facter.value(:osfamily) == 'windows'
        # change the listener service to start automatically on windows reboot
        listener_start_cmd = "sc config OracleOraDB12cHomeTNSListener" + listener_name + " start=auto"
        system(listener_start_cmd)
      end
    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Oracle listener starting failed: #{e.message}"
    end
  end


  def pre_delete()
    oracle_home = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    listener_name = resource[:listener_name]
    inventory_location = resource[:oracle_inventory_location]

    # stop the listener
    stop_listener(oracle_home, listener_name, deploy_user)

    # deinstall oracle server home
    deinstall_oracle_server_home(oracle_home, deploy_user, inventory_location)

    oracle_base = File.dirname(oracle_home)
    FileUtils.rm_rf(oracle_base)

    @property_hash[:ensure] = :absent
  end

  def create_listener_file(listener_file, listener_name, listener_port)
    listener_host = Facter.value(:fqdn)

    open(listener_file,  'w') do |listener|
      listener.puts("# listener.ora Network Configuration File: #{listener_file}")
      listener.puts('# Generated by Oracle configuration tools.')
      listener.puts()
      listener.puts("#{listener_name} =")
      listener.puts("  (DESCRIPTION_LIST =")
      listener.puts("    (DESCRIPTION =")
      listener.puts("      (ADDRESS = (PROTOCOL = TCP)(HOST = #{listener_host})(PORT = #{listener_port}))")
      listener.puts("      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC#{listener_port}))")
      listener.puts("    )")
      listener.puts("  )")
    end
  end

  def start_listener(oracle_home, listener_name, oracle_user)
    # start the listener
    listener_cmd = File.join(oracle_home, 'bin', 'lsnrctl')

    if Facter.value(:osfamily) == 'windows'
      listener_start_cmd = "#{listener_cmd} start #{listener_name}"
    else
      ENV['ORACLE_HOME'] = oracle_home
      ENV['LD_LIBRARY_PATH'] = "#{oracle_home}/lib:$LD_LIBRARY_PATH"

      listener_start_cmd = "su #{oracle_user} -c \"#{listener_cmd} start #{listener_name}\""
    end
    begin
      Puppet::Util::Execution.execute(listener_start_cmd, :failonfail => true)
      Puppet.debug('Oracle listener started successfully')
    rescue Puppet::ExecutionFailure => e
      if e.message.include?("TNS-01106: Listener using listener name #{listener_name} has already been started") == false
        raise Puppet::ExecutionFailure, "Oracle listener starting failed: #{e.message}"
      else
        Puppet.debug("Listener #{listener_name} already started")
      end
    end
  end

  def stop_listener(oracle_home, listener_name, oracle_user)
    # stop the listener
    listener_cmd = File.join(oracle_home, 'bin', 'lsnrctl')

    if Facter.value(:osfamily) == 'windows'
      listener_stop_cmd = "#{listener_cmd} stop #{listener_name}"
    else
      ENV['ORACLE_HOME'] = oracle_home
      ENV['LD_LIBRARY_PATH'] = "#{oracle_home}/lib:$LD_LIBRARY_PATH"

      listener_stop_cmd = "su  #{oracle_user} -c \"#{listener_cmd} stop #{listener_name}\""
    end
    begin
      Puppet::Util::Execution.execute(listener_stop_cmd, :failonfail => true)
      Puppet.debug('Oracle listener stopped successfully')
    rescue Puppet::ExecutionFailure => e
      Puppet.debug("Oracle listener stopping failed: #{e.message}")
    end
  end

  def apply_patch(ods_patch, patch_dir)

    oracle_home = resource[:deploy_location]
    if Facter.value(:osfamily) == 'windows'
      oracle_home = oracle_home.gsub('/', '\\')
      patch_dir = patch_dir.gsub('/', '\\')
    end
    Puppet.debug("Installing Oracle Server patch #{ods_patch} from #{patch_dir}")
    ENV['ORACLE_HOME'] = oracle_home

    scripts_dir = File.dirname(__FILE__)
    Puppet.debug("Current file directory #{scripts_dir}")
    opatch_response_file = "#{scripts_dir}/../../../../files/pt_database/opatch.erb"
    Puppet.debug("OPatch response file: #{opatch_response_file}")
    FileUtils.cp(opatch_response_file, patch_dir)

    begin
      if Facter.value(:osfamily) == 'windows'
        patch_apply_cmd = "cd #{patch_dir} && #{oracle_home}\\OPatch\\opatch.bat " + \
        " apply -silent -ocmrf #{patch_dir}\\opatch.erb"
        Puppet.debug("Oracle Server patch apply command #{patch_apply_cmd}")
        system(patch_apply_cmd)
        if $? == 0
          Puppet.debug("Oracle Server Patch #{ods_patch} install successful")
        else
          Puppet.debug("Oracle Server Patch #{ods_patch} install failed")
        end
      else
        deploy_user = resource[:deploy_user]

        cmd_prefix = "su - #{deploy_user} -c \""
        cmd_suffix = "\""
        patch_apply_cmd = "#{cmd_prefix} cd #{patch_dir} && #{oracle_home}/OPatch/opatch " + \
        " apply -silent -ocmrf #{patch_dir}/opatch.erb#{cmd_suffix}"
        Puppet.debug("Oracle Server patch apply command #{patch_apply_cmd}")

        Puppet::Util::Execution.execute(patch_apply_cmd, :failonfail => true)
        Puppet.debug('Oracle Server patch installation successfully')
      end
    rescue Puppet::ExecutionFailure => e
      Puppet.debug("Oracle Server patch installation failed: #{e.message}")
      raise Puppet::Error, "Installation of Oracle Server patch #{ods_patch} failed: #{e.message}"
    end
  end
end
