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

require 'etc'
require 'csv'
require 'fileutils'
require 'tempfile'
require 'open3'

if Facter.value(:osfamily) == 'windows'
  require 'win32/registry'
end

module PtCompUtils
  module Validations

    def self.included(parent)
      parent.extend(Validations)
    end

    def validate_keyvalue_array(value)
      value = [value] unless value.is_a? Array
      value.each do |item|
        # validate to make sure the  value is either 'Yes' or 'No'
        val = item.split('=')[1].strip
        if val != 'Yes' && val != 'No'
          fail("Setting value should be either 'Yes' or 'No'")
        end
      end
    end

    def validate_oracle_user_and_group(user_name, user_group)
      if user_name.nil?
        fail("oracle_user attribute should be specified for setting up " +
             "a PeopleSoft database on Unix platforms")
      end
      if user_group.nil?
        fail("oracle_user_group attribute should be specified for setting up " +
             "a PeopleSoft database on Unix platforms")
      end
    end

    def check_user_group(user_name, user_group)
      user_info = nil
      group_info = nil

      begin
        user_info = Etc.getpwnam(user_name)
      rescue ArgumentError
        fail Puppet::Error, "OS User #{user_name} does not exists"
     end

      begin
        group_info = Etc.getgrnam(user_group)
      rescue ArgumentError
        fail Puppet::Error, "OS Group #{value} does not exists"
      end
      user_gid = user_info.gid
      Puppet.debug("User group id: #{user_gid}")
      group_gid = group_info.gid
      Puppet.debug("Group group id: #{group_gid}")
      group_members = group_info.mem
      Puppet.debug("Group members: #{group_members.inspect}")

      if (user_gid != group_gid) and
         (group_members.include?(user_name) == false)
         fail("User #{user_name} does not belong to group #{user_group}")
      end
    end

    def os_user_exists?(user_name)
      begin
        Etc.getpwnam(user_name)
        true
      rescue ArgumentError
        false
     end
    end

    def validate_domain_params(os_user, ps_home_dir)
      # make sure os user is specified, if the os family is not windows
      if Facter.value(:osfamily) != 'windows' and os_user.nil?
        fail("os_user attribute should be specified for managing " +
             "a Tuxedo/Webserver domain on Unix platforms")
      end
      if ps_home_dir.nil?
        fail("Domain home attribute should be specified for managing " +
             "a Tuxedo/Webserver domain")
      end
    end

    def validate_params_exists(os_user, ps_home_dir)
      # make sure os user is specified, if the os family is not windows
      if Facter.value(:osfamily) != 'windows'
        begin
          Etc.getpwnam(os_user)
        rescue
          fail("os_user #{os_user} does not exists")
        end
      end
      unless FileTest.directory?(ps_home_dir)
        fail("Directory #{ps_home_dir} does not exists")
      end
    end

    def validate_thirdparty_components(oracle_home_dir, tuxedo_home_dir)
      if Facter.value(:osfamily) != 'windows'
        if oracle_home_dir.nil?
          fail("oracle_home_dir attribute should be specified")
        end
        if tuxedo_home_dir.nil?
          fail("tuxedo_home_dir attribute should be specified")
        end
      end
    end

    def check_thirdparty_homes(oracle_home_dir, tuxedo_home_dir)
      if Facter.value(:osfamily) != 'windows'
        # make sure the homes exists
        unless FileTest.directory?(oracle_home_dir)
          raise ArgumentError,
            "Oracle Home directory #{oracle_home_dir} does not exists"
        end
        unless FileTest.directory?(tuxedo_home_dir)
          raise ArgumentError, 
            "Tuxedo Home directory #{tuxedo_home_dir} does not exists"
        end
      end
    end

    def validate_port(port_num)
      if Facter.value(:osfamily) != 'windows'
        search_cmd = 'grep -i '
        search_string = 'LISTEN'
        tcp_string = 'TCP'
        null_suffix = ' >/dev/null'
      else
        search_cmd ='find /I '
        search_string = 'LISTENING'
        tcp_string = 'tcp'
        null_suffix = ' >/NUL'
      end
      port_check_cmd = "netstat -an | #{search_cmd} \":#{port_num}\s\" | #{search_cmd} \"#{tcp_string}\" | #{search_cmd} \"#{search_string}\" #{null_suffix}"
      Puppet.debug("Port validation cmd: #{port_check_cmd}")
      system(port_check_cmd)
      if $? == 0
        error_msg = "Port #{port_num} already in use"
        Puppet.debug(error_msg)
        raise ArgumentError, "#{error_msg}"
      end
    end
  end
end
