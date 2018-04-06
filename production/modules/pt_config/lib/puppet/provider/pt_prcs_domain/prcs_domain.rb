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

require 'puppet/provider/psftdomain'
require 'open3'

if Facter.value(:osfamily) == 'windows'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_prcs_domain).provide :prcs_domain,
                  :parent => Puppet::Provider::PsftDomain do

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  mk_resource_methods

  def feature_settings=(value)
     @property_flush[:feature_settings] = value
  end

  def config_settings=(value)
    @property_flush[:config_settings] = value
  end

  def env_settings=(value)
  end

  def create
    pre_create()

    domain_name = resource[:domain_name]
    domain_type = get_domain_type()
    template_type = get_template_type()

    Puppet.debug("Creating PRCS domain: #{domain_name}")
    cmd_file = create_psadmin_cmd_file("#{get_startup_settings} #{get_env_settings}")

    begin
      psadmin_cmd = File.join(resource[:ps_home_dir], 'appserv', 'psadmin')
      if Facter.value(:osfamily) == 'windows'

        command = "#{psadmin_cmd} #{domain_type} create -d #{domain_name} #{template_type} #{get_startup_settings} #{get_env_settings}"
        Open3.popen3(command) do |stdin, out, err, wait_thr|
          error_str = err.read
          out_str = out.read

          if wait_thr.value.success?
            Puppet.debug("Command executed successfully")
          else
            if out_str.include?('installation incomplete!') == false
              raise Puppet::ExecutionFailure, "Command execution failed, error: #{error_str} "
            else
              Puppet.debug("Command executed successfully")
            end
          end
        end
      elsif Facter.value(:osfamily) == 'Solaris'
        domain_cmd('-',  resource[:os_user], '-c',
                   "#{psadmin_cmd} #{domain_type} create -d #{domain_name} " +
                   "#{template_type} -@@ #{cmd_file}")
      elsif Facter.value(:kernel) == 'Linux'
        domain_cmd('-m', '-s', '/bin/bash', '-l',  resource[:os_user], '-c',
                   "#{psadmin_cmd} #{domain_type} create -d #{domain_name} " +
                   "#{template_type}  -@@ #{cmd_file}")
      elsif Facter.value(:kernel) == 'AIX'
        domain_cmd('-',  resource[:os_user], '-c',
                   "#{psadmin_cmd} #{domain_type} create -d #{domain_name} " +
                   "#{template_type} -@@ #{cmd_file}")
      end
    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Unable to create domain #{domain_name}: #{e.message}"
    end
    FileUtils.remove_file(cmd_file, :force => true)
    post_create()
    @property_hash[:ensure] = :present
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


  def get_startup_settings
    empty_param = "_____"

    if @db_hash[:db_type] == 'MSSQL'
      db_type = 'MICROSFT'
    else
      db_type = @db_hash[:db_type]
    end
    if db_type == 'MICROSFT'
      sqr_db_type = 'MSS'
    elsif db_type == 'DB2ODBC'
      sqr_db_type = 'DB2'
    elsif db_type == 'DB2UNIX'
      sqr_db_type = 'DBX'
    else
      sqr_db_type = 'ORA'
    end

    if Facter.value(:osfamily) == 'windows'
      param_separator = '/'

      dbdir = resource[:db_home_dir]
      if dbdir.nil?
        bin_path = "%PS_HOME%\\bin"
      else
        bin_path = File.join(dbdir, 'bin')
        bin_path = bin_path.gsub('/', '\\')
        bin_path = "\"#{bin_path}\""
      end

      log_output_dir = "%PS_SERVDIR%\\log_output"
      sqr_db_type = sqr_db_type.downcase
      sqr_bin_dir = "%PS_HOME%\\bin\\sqr\\#{sqr_db_type}\\binw"
    else
      param_separator = ','
      bin_path = "."

      log_output_dir = "%PS_SERVDIR%/log_output"
      sqr_bin_dir = "%PS_HOME%/bin/sqr/#{sqr_db_type}/bin"
    end

    domain_name = resource[:domain_name]
    if @db_hash.size != 0
      default_param = "."

      db_server_name = @db_hash[:db_server_name]
      if db_server_name.nil?
        db_server_name = empty_param
      end

      if Facter.value(:osfamily) == 'windows'
        startup_settings = @db_hash[:db_name] + param_separator + \
                         db_type + param_separator + \
                         domain_name + param_separator + \
                         @db_hash[:db_opr_id] + param_separator + \
                         @db_hash[:db_opr_pwd] + param_separator + \
                         @db_hash[:db_connect_id] + param_separator + \
                         @db_hash[:db_connect_pwd] + param_separator + \
                         db_server_name + param_separator + \
                         log_output_dir + param_separator + \
                         sqr_bin_dir + param_separator + \
                         empty_param + param_separator + \
                         bin_path + param_separator + empty_param
      else
        startup_settings = @db_hash[:db_name] + param_separator + \
                         db_type + param_separator + \
                         domain_name + param_separator + \
                         @db_hash[:db_opr_id] + param_separator + \
                         @db_hash[:db_opr_pwd] + param_separator + \
                         @db_hash[:db_connect_id] + param_separator + \
                         @db_hash[:db_connect_pwd] + param_separator + \
                         db_server_name + param_separator + \
                         log_output_dir + param_separator + \
                         sqr_bin_dir + param_separator + \
                         bin_path + param_separator
      end

    else
      startup_settings = doman_name
    end
    Puppet.debug("Startup settings: #{startup_settings.gsub(@db_hash[:db_opr_pwd], '****').gsub(@db_hash[:db_connect_pwd], '****')}")
    return "#{get_startup_option} #{startup_settings}"
  end

  def get_startup_option
    return "-ps"
  end

  def get_template_type
    if Facter.value(:osfamily) == 'windows'
      prcs_type = "windows"
    else
      prcs_type = "unix"
    end
    return "-t #{prcs_type}"
  end

  def get_domain_type
    return "-p"
  end

  def pre_create
    super()

    domain_name = resource[:domain_name]
    cfg_home_dir = resource[:ps_cfg_home_dir]

    domain_dir = File.join(cfg_home_dir, 'appserv', 'prcs', domain_name)
    if File.exist?(domain_dir)
      Puppet.debug("Removing Process Scheduler domain directory: #{domain_dir}")
      FileUtils.rm_rf(domain_dir)
    end
  end

  def post_delete
    domain_name = resource[:domain_name]
    cfg_home_dir = resource[:ps_cfg_home_dir]
    Puppet.debug("Removing Process Scheduler domain directory")
    FileUtils.rm_rf(File.join(cfg_home_dir, 'appserv', 'prcs', domain_name))

    if Facter.value(:osfamily) == 'windows'
      prcs_domain_service = "PsftPrcsDomain#{domain_name}Service"
      begin
        # stop the windows service
        Service.stop(prcs_domain_service)
      rescue Exception => e
        Puppet.debug("Error while stopping windows Service #{prcs_domain_service}: #{e.message}")
        system("sc stop #{prcs_domain_service} > NUL")
      end
      begin
        # delete the windows service
        Service.delete(prcs_domain_service)
      rescue Exception => e
        Puppet.debug("Error while deleting windows Service #{prcs_domain_service}: #{e.message}")
        system("sc delete #{prcs_domain_service} > NUL")
      end
    end
  end
end
