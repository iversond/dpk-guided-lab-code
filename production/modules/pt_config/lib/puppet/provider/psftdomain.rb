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
require 'tempfile'
require 'tmpdir'
require 'etc'
require 'puppet/provider/pt_utils'
require 'pt_comp_utils/validations'
require 'pt_comp_utils/database'

class Puppet::Provider::PsftDomain < Puppet::Provider
  include ::PtCompUtils::Validations
  include ::PtCompUtils::Database

  @db_hash = {}

  def initialize(value={})
    super(value)
    Puppet.debug("Provider Initialization")
    @property_flush = {}
  end

  def db_hash=(db_hash)
    Puppet.debug("Caching DB connectivity")
    @db_hash = db_hash
  end

  def exists?
    # check if recreate is specified
    if resource[:ensure] == :present and resource[:recreate] == true
      Puppet.debug("Recreate set to true")
      destroy()
    end
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end
    ps_home_dir = resource[:ps_home_dir]
    unless FileTest.directory?(ps_home_dir)
      false
    end
    begin
      # for Unix, check to see if the user exists
      if Facter.value(:osfamily) != 'windows'
        os_user = resource[:os_user]
        begin
          user_info = Etc.getpwnam(os_user)
        rescue ArgumentError
          @property_hash[:ensure] = :absent
          Puppet.debug("Resource does not exists: User #{os_user} doesnt exist")
          return false
        end
      end
      if Facter.value(:osfamily) == 'windows'
        psadmin_cmd = File.join(resource[:ps_home_dir], 'appserv', 'psadmin.exe')
      else
        psadmin_cmd = File.join(resource[:ps_home_dir], 'appserv', 'psadmin')
      end
      if FileTest.exists?(psadmin_cmd) == false
          @property_hash[:ensure] = :absent
          Puppet.debug("psadmin command #{psadmin_cmd} doesnt exist")
          return false
      end

      domain_name = resource[:domain_name]
      status_output = execute_psadmin_action(get_status_command)
      Puppet.debug("Status output: #{status_output}")
      if status_output.include?("Domain not found: #{domain_name}")
        @property_hash[:ensure] = :absent
        Puppet.debug("Resource does not exists: #{status_output}")
        false
      else
        @property_hash[:ensure] = :present
        Puppet.debug("Resource exists")
        true
      end
    rescue Puppet::Error => e
      @property_hash[:ensure] = :absent
      Puppet.debug("Resource does not exists: #{e.message}")
      false
    end
  end

  def create
    pre_create()

    domain_name = resource[:domain_name]
    domain_type = get_domain_type()
    template_type = get_template_type()

    Puppet.debug("Creating domain: #{domain_name}")
    cmd_file = create_psadmin_cmd_file("#{get_startup_settings} #{get_env_settings}")

    begin
      psadmin_cmd = File.join(resource[:ps_home_dir], 'appserv', 'psadmin')
      if Facter.value(:osfamily) == 'windows'

        command = "#{psadmin_cmd} #{domain_type} create -d #{domain_name} #{template_type} #{get_startup_settings} #{get_env_settings}"
        execute_command(command)
      elsif Facter.value(:osfamily) == 'Solaris' 
          domain_cmd('-', resource[:os_user], '-c',
                   "#{psadmin_cmd} #{domain_type} create -d #{domain_name} " +
                   "#{template_type} -@@ #{cmd_file}")
      elsif Facter.value(:kernel) == 'Linux'
          domain_cmd('-m', '-s', '/bin/bash', '-l',  resource[:os_user], '-c',
                   "#{psadmin_cmd} #{domain_type} create -d #{domain_name} " +
                   "#{template_type} -@@ #{cmd_file}")
      elsif Facter.value(:kernel) == 'AIX'
          domain_cmd('-', resource[:os_user], '-c',
                   "#{psadmin_cmd} #{domain_type} create -d #{domain_name} " +
                   "#{template_type} -@@ #{cmd_file}")
      end

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error,
          "Unable to create domain #{domain_name}: #{e.message}"
    end

    FileUtils.remove_file(cmd_file, :force => true)
    post_create()
    @property_hash[:ensure] = :present
  end

  def destroy
    ps_home_dir = resource[:ps_home_dir]
    os_user = resource[:os_user]
    validate_params_exists(os_user, ps_home_dir)

    pre_delete()

    stop_domain()
    delete_domain()

    post_delete()

    @property_hash[:ensure] = :absent
    @property_flush.clear
  end

  def flush
    domain_name = resource[:domain_name]
    Puppet.debug("Flush called for domain: #{domain_name}")

    if @property_flush.size == 0
      Puppet.debug("Nothing to flush")
      return
    end
    stop_domain()

    @property_flush[:db_settings] = @db_hash unless @db_hash.size == 0
    configure_domain()

    domain_start = resource[:domain_start]
    if domain_start.to_s == "true"
      Puppet.debug("Domain start requested")
      start_domain()
    end
    @property_hash = resource.to_hash
  end

  def self.instances
    []
  end

  private

  def create_psadmin_cmd_file(psadmin_parameters)
    # genenrate the Psadmin cmd file
    temp_dir_name = Dir.tmpdir
    rand_num = rand(1000)
    file_prop_path = File.join(temp_dir_name, "temp_psadmin_#{rand_num}.txt")
    file_prop = File.open(file_prop_path, 'w')
    file_prop.puts psadmin_parameters
    file_prop.close
    File.chmod(0755, file_prop_path)
    return file_prop_path
  end

  def pre_create
    domain_name = resource[:domain_name]
    Puppet.debug("Pre create domain: #{domain_name}")

    ps_home_dir = resource[:ps_home_dir]
    os_user = resource[:os_user]
    validate_params_exists(os_user, ps_home_dir)

    # make sure Database properties are given
    if @db_hash.nil? || @db_hash.size == 0
      raise ArgumentError, "db_settings needs to be specified " +
                           "to create a Tuxedo domain"
    end
  end

  def post_create
    domain_name = resource[:domain_name]
    Puppet.debug("Post create domain: #{domain_name}")

    # flush to configure and start the domain
    # stick the properties into the flush hash and call configure
    if ! resource[:feature_settings].nil?
      @property_flush[:feature_settings] = resource[:feature_settings]
    end

    if ! resource[:config_settings].nil?
      @property_flush[:config_settings] = resource[:config_settings]
    end

    configure_domain()

    domain_start = resource[:domain_start]
    if domain_start.to_s == "true"
      Puppet.debug("Domain start requested")
      start_domain()
    end
  end

  def configure_domain
    domain_name = resource[:domain_name]
    domain_type = get_domain_type()

    Puppet.debug("Configuring domain: #{domain_name}")
    if @property_flush.size == 0
      Puppet.debug("Nothing to configure")
      return
    end

    config_settings_separator = '#'
    if Facter.value(:osfamily) == 'windows'
      feature_settings_separator = '/'
    else
      feature_settings_separator = '%'
    end

    if @property_flush.has_key?(:db_settings)
    end

    feature_settings = @property_flush[:feature_settings]
    if ! feature_settings.nil?
      feature_settings = strip_keyval_array(feature_settings)
      feature_settings = regsubst_array(feature_settings,
                                        '^(.*)=(.*)$', '{\1}=\2')
      feature_settings = feature_settings.join(feature_settings_separator)
      Puppet.debug("Feature settings: #{feature_settings.inspect}")
      feature_settings = "-u \"#{feature_settings}\""
    else
      feature_settings = ''
    end

    config_settings = @property_flush[:config_settings]
    if ! config_settings.nil?
      Puppet.debug("Config settings: #{config_settings.inspect}")
      config_settings = strip_keyval_array(config_settings)
      config_settings = regsubst_array(config_settings,
                                       '^(.*?)/(.*)$', '[\1]/\2')
      config_settings = config_settings.join(config_settings_separator)
      Puppet.debug("Config settings: #{config_settings.inspect}")
      config_settings = "-cfg \"#{config_settings}\""
    else
      config_settings = ''
    end
    config_args = "#{feature_settings} #{config_settings}"

    begin
      psadmin_cmd = File.join(resource[:ps_home_dir], 'appserv', 'psadmin')

      if Facter.value(:osfamily) == 'windows'
        command = "#{psadmin_cmd} #{domain_type} configure -d #{domain_name} #{config_args}"
        command_output = execute_command(command)
      elsif  Facter.value(:osfamily) == 'Solaris'
        command_output = domain_cmd('-', resource[:os_user], '-c',
                          "#{psadmin_cmd} #{domain_type} configure -d " +
                          "#{domain_name}  #{config_args}")
      elsif Facter.value(:kernel) == 'Linux'
        command_output = domain_cmd('-m', '-s', '/bin/bash', '-l',  resource[:os_user], '-c',
                          "#{psadmin_cmd} #{domain_type} configure -d " +
                          "#{domain_name}  #{config_args}")
      elsif Facter.value(:kernel) == 'AIX'
        command_output = domain_cmd('-', resource[:os_user], '-c',
                          "#{psadmin_cmd} #{domain_type} configure -d " +
                          "#{domain_name}  #{config_args}")
      end
      Puppet.debug("Config outout: #{command_output}")

    rescue Puppet::ExecutionFailure => e
     if Facter.value(:kernel) == 'Linux'
           command_output = domain_cmd('-m', '-s', '/bin/bash', '-l',  resource[:os_user], '-c',
           "#{psadmin_cmd} #{domain_type} configure -d " +
           "#{domain_name}  #{config_args}")
  
              if command_output.include? 'Process Scheduler Server configuration complete'
                 return command_output
              end
     end
    raise Puppet::Error,
          "Unable to configure domain: #{e.message}"
    end

    @property_flush.clear
  end

  def stop_domain
    # check the status of the domain before stopping
    command_output = execute_psadmin_action(get_status_command)
    if command_output.include? 'ERROR'
      Puppet.debug("Domain #{resource[:domain_name]} already stopped")
      return
    end
    execute_psadmin_action('shutdown!')
  end

  def delete_domain
    if Facter.value(:osfamily) == 'windows'
      Puppet.debug("Removing tuxipc processes")
      tuxipc_remove_cmd = "TASKKILL /F /IM tuxipc.exe /T >NUL 2>&1"
      system(tuxipc_remove_cmd)
    end
    execute_psadmin_action('delete!')
  end

  def post_delete
  end

  def start_domain
    command_output = execute_psadmin_action('start')
    if command_output.include? 'tmshutdown'
      raise Puppet::Error,
          "Unable to start domain: #{command_output}"
    end
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
      elsif Facter.value(:osfamily) == 'Solaris'
          command_output = domain_cmd('-', resource[:os_user], '-c',
                          "#{psadmin_cmd} #{domain_type} #{action} " +
                          "-d #{domain_name}")
      elsif Facter.value(:kernel) == 'Linux'
          command_output = domain_cmd('-m', '-s', '/bin/bash', '-',  resource[:os_user], '-c',
                          "#{psadmin_cmd} #{domain_type} #{action} " +
                          "-d #{domain_name}")
      elsif Facter.value(:kernel) == 'AIX'
          command_output = domain_cmd('-', resource[:os_user], '-c',
                          "#{psadmin_cmd} #{domain_type} #{action} " +
                          "-d #{domain_name}")
      end
      return command_output

    rescue Puppet::ExecutionFailure => e
      if e.message.include?('returned 40')
        return "ERROR: Not Found"
      else
        raise Puppet::Error, "Unable to perform action #{action}: #{e.message}"
      end
    end
  end

  def get_env_settings
    env_settings_separator = '#'

    env_settings = resource[:env_settings]
    if ! env_settings.nil?
      env_settings = strip_keyval_array(env_settings)
      env_settings = regsubst_array(env_settings,
                                    '^(.*)=(.*)$', '\1=\2')
      env_settings = env_settings.join(env_settings_separator)
      Puppet.debug("ENV settings: #{env_settings.inspect}")
      env_settings = "-env \'#{env_settings}\'"
    else
      env_settings = ''
    end
    return env_settings
  end

  def get_status_command
    return "sstatus"
  end

  def pre_delete
    if Facter.value(:osfamily) == 'windows'
      # for windows 2012, the Tux domain start is starting an rmiregistry process
      # that is holding onto some of the AppServer files and as a result the removal of
      # Tux domain is failing
      rmireg_remove_cmd = "TASKKILL /F /IM rmiregistry.exe >NUL 2>&1"
      system(rmireg_remove_cmd)

      tuxipc_remove_cmd = "TASKKILL /F /IM tuxipc.exe /T >NUL 2>&1"
      system(tuxipc_remove_cmd)
    else
      # on some unix platforms the rmiregistry is still being held by the domain user
      # even after shutting down the domain. This is causing the user not to be deleted
      # this is a workaround to remove these processes before cleaning up the domain
      rmi_cleanup_script = Tempfile.new(['rmi-cleanup', '.sh'])
      rmi_cleanup_script.puts("#!/bin/sh")
      rmi_cleanup_script.puts()
      rmi_cleanup_script.puts("rmi_list=$(ps aux | grep rmiregistry | grep -v grep  | awk '{print $2}')")
      rmi_cleanup_script.puts("for rmi_pid in $rmi_list; do")
      rmi_cleanup_script.puts("  kill -9 $rmi_pid >/dev/null 2>&1")
      rmi_cleanup_script.puts("done")
      rmi_cleanup_script.close
      rmi_cleanup_script_file = rmi_cleanup_script.path
      File.chmod(0755, rmi_cleanup_script_file)
      system("sh #{rmi_cleanup_script_file}")
    end
  end

  def get_startup_settings
    raise ArgumentError, "Subclasses should implement this method"
  end

  def get_domain_type
    raise ArgumentError, "Subclasses should implement this method"
  end

  def get_startup_option
    raise ArgumentError, "Subclasses should implement this method"
  end

  def get_template_type
    raise ArgumentError, "Subclasses should implement this method"
  end
end
