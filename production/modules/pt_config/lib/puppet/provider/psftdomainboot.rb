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

require 'puppet/provider'
require 'pt_comp_utils/database'
require 'pt_comp_utils/validations'
require 'puppet/provider/pt_utils'

class Puppet::Provider::PsftDomainBoot < Puppet::Provider
  include ::PtCompUtils::Database
  include ::PtCompUtils::Validations

  def self.instances
    []
  end

  # How to restart the domain
  def restart
    Puppet.debug("Action restart called")
    self.stop_domain
    self.start_domain
  end

  # get the status of the domain
  def status
    Puppet.debug("Action status called")
    domain_name = resource[:domain_name]

    command_output = execute_psadmin_action('sstatus')
    if command_output.include?("BBL")
      Puppet.debug("Domain #{domain_name} status is running")
      return :running
    else
      Puppet.debug("Domain #{domain_name} status is stopped")
      return :stopped
    end
  end

  def stop_domain
    Puppet.debug("Action stop called on parent")

    # check the status of the domain before stopping
    command_output = execute_psadmin_action('sstatus')
    if command_output.include?('BBL')
      execute_psadmin_action('shutdown!')
    else
      Puppet.debug("Domain #{resource[:domain_name]} already stopped")
    end
  end

  def start_domain
    Puppet.debug("Action start called on parent")

    command_output = execute_psadmin_action('start')
    if command_output.include? 'tmshutdown'
      raise Puppet::ExecutionFailure, "Unable to start domain: #{command_output}"
    end
  end

  private

  def get_domain_type
    raise ArgumentError, "Subclasses should implement this method"
  end

  def execute_psadmin_action(action)
    domain_name = resource[:domain_name]
    domain_type = get_domain_type()

    Puppet.debug("Performing action #{action} on domain #{domain_name}")

    begin
      psadmin_cmd = File.join(resource[:ps_home_dir], 'appserv', 'psadmin')
      if Facter.value(:osfamily) == 'windows'

        set_user_env()
        command = "#{psadmin_cmd} #{domain_type} #{action} -d #{domain_name}"
        command_output = execute_command(command)

      else
        os_user = resource[:os_user]
        if os_user_exists?(os_user) == false
            command_output="ERROR: os user #{os_user} does not exists"
        elsif Facter.value(:osfamily) == 'Solaris' 
            command_output = domain_cmd('-', resource[:os_user], '-c',
               "#{psadmin_cmd} #{domain_type} #{action} " + "-d #{domain_name}")
        elsif Facter.value(:kernel) == 'Linux'
            command_output = domain_cmd('-m', '-s', '/bin/bash', '-',  os_user, '-c',
               "#{psadmin_cmd} #{domain_type} #{action} " + "-d #{domain_name}")
        elsif Facter.value(:kernel) == 'AIX'
            command_output = domain_cmd('-', resource[:os_user], '-c',
               "#{psadmin_cmd} #{domain_type} #{action} " + "-d #{domain_name}")
        end
      end
      return command_output

    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Unable to perform action #{action}: #{e.message}"
    end
  end

  def get_db_type()
    # parse the peopletools properties file
    pt_prop_file = File.join(resource[:ps_home_dir], 'peopletools.properties')
    pt_prop_hash = {}
    pt_prop_fp = File.open(pt_prop_file)
    pt_prop_fp.each_line {|item|
      prop = item.split('=')
      if prop[1].nil? == false
        pt_prop_hash[item.split('=')[0]] = item.split('=')[1].chomp
      end
    }
    pt_prop_fp.close()
    db_type_key = 'psplatformregname'
    db_type = pt_prop_hash[db_type_key]

    return db_type
  end
end

