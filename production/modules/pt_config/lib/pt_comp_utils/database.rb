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

require 'fileutils'
require 'tmpdir'
require 'open3'
require 'easy_type'

if Facter.value(:osfamily) == 'windows'
    require 'win32/registry'
end

module PtCompUtils
  module Database

  def self.included(parent)
    parent.extend(Database)
  end

  def execute_sql_command(oracle_home_dir, oracle_sid, command, oracle_user = nil)
    Puppet.debug "Executing SQL command #{command}"

    sql_script_file = sql_command_file(template('puppet:///modules/pt_config/pt_psft_database/command.sql.erb', binding))

    execute_sql_command_file(oracle_home_dir, oracle_sid, sql_script_file, oracle_user, nil)
  end

  def execute_pdb_sql_command(oracle_home_dir, database_name, command, oracle_user = nil)
    Puppet.debug "Executing SQL command #{command}"

    sql_script_file = sql_command_file(template('puppet:///modules/pt_config/pt_psft_database/command.sql.erb', binding))

    execute_pdb_sql_command_file(oracle_home_dir, database_name, sql_script_file, oracle_user, nil)
  end

  def execute_sql_command_file(oracle_home_dir, oracle_sid, sql_script_file, oracle_user = nil, *sql_args)

    if sql_args.nil?
      sql_script_args = ''
    else
      sql_script_args = "#{sql_args.join(' ')}"
    end

    cur_path = ENV['PATH']
    if Facter.value(:osfamily) == 'windows'
      oracle_home_dir = oracle_home_dir.gsub('/', '\\')
      new_path = "#{oracle_home_dir}/bin;#{cur_path}"
      sql_cmd = "sqlplus.exe -S -L / as sysdba @#{sql_script_file} #{sql_script_args}"
    else
      new_path = "#{oracle_home_dir}/bin:#{cur_path}"
      if Facter.value(:osfamily) == 'Solaris' or Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
        sql_cmd = "su - #{oracle_user} -c \"sqlplus -S -L / as sysdba @#{sql_script_file} #{sql_script_args}\" -s"
      else
        sql_cmd = "su -s /bin/bash #{oracle_user} -c \"sqlplus -S -L / as sysdba @#{sql_script_file} #{sql_script_args}\""
    end
    end
    ENV['ORACLE_HOME'] = oracle_home_dir
    ENV['ORACLE_SID'] = oracle_sid
    ENV['PATH'] = new_path

    error_str = ''
    out_str = ''
    begin
      Puppet.debug("Executing SQL command file: #{sql_cmd}")
      Open3.popen3(sql_cmd) do |stdin, out, err|
        stdin.close
        out_str = out.read
        error_str = err.read
      end
    rescue Exception => e
      fail("Error running SQL script, Exception: #{e.message}, Error: #{error_str}")
    ensure
      ENV['PATH'] = cur_path
      FileUtils.remove_file(sql_script_file, :force => true)
    end
    Puppet.debug("SQL command output: #{out_str}, error: #{error_str}")
    return out_str + error_str
  end

  def execute_pdb_sql_command_file(oracle_home_dir, database_name, sql_script_file, oracle_user = nil, db_admin_pwd = nil, *sql_args)

    if sql_args.nil?
      sql_script_args = ''
    else
      sql_script_args = "#{sql_args.join(' ')}"
    end

    if db_admin_pwd.nil?
      fail("Error running SQL script, Either you have to give the container name or db admin passord")
    end
    cur_path = ENV['PATH']
    if Facter.value(:osfamily) == 'windows'
      set_user_env()

      oracle_home_dir = oracle_home_dir.gsub('/', '\\')
      new_path = "#{oracle_home_dir}/bin;#{cur_path}"
      sql_cmd = "sqlplus.exe -S -L system/#{db_admin_pwd}@#{database_name} @#{sql_script_file} #{sql_script_args}"
    else
      new_path = "#{oracle_home_dir}/bin:#{cur_path}"
      if Facter.value(:osfamily) == 'Solaris' or Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
         sql_cmd = "su - #{oracle_user} -c \"sqlplus -S -L system/#{db_admin_pwd}@#{database_name} @#{sql_script_file} #{sql_script_args}\" -s"
      else   
        sql_cmd = "su -s /bin/bash - #{oracle_user} -c \"sqlplus -S -L system/#{db_admin_pwd}@#{database_name} @#{sql_script_file} #{sql_script_args}\""
      end
    end
    ENV['ORACLE_HOME'] = oracle_home_dir
    ENV['PATH'] = new_path

    error_str = ''
    out_str = ''
    begin
      Puppet.debug("Executing SQL command: #{sql_cmd}".sub!("#{db_admin_pwd}", "****"))
      Open3.popen3(sql_cmd) do |stdin, out, err|
        stdin.close
        out_str = out.read
        error_str = err.read

        ENV['PATH'] = cur_path
    end
    rescue
      ENV['PATH'] = cur_path
      FileUtils.remove_file(sql_script_file, :force => true)
      fail("Error running SQL script, Error: #{error_str}")
    end
    Puppet.debug("SQL command output: #{out_str}, error: #{error_str}")
    return out_str + error_str
  end

  def set_tns_registry(new_tnsadmin_dir)
    if Facter.value(:osfamily) != 'windows'
      Puppet.debug("Not a Windows platform, nothing to set")
    end
    begin
      Puppet.debug("Setting the TNS_ADMIN value in registry to #{new_tnsadmin_dir}")
      Win32::Registry::HKEY_LOCAL_MACHINE.open("SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment", Win32::Registry::KEY_ALL_ACCESS) do |reg|
        cur_tnsadmin_dir = reg['TNS_ADMIN']
        Puppet.debug("Current TNS_ADMIN value in registry: [#{cur_tnsadmin_dir}]")
        if (new_tnsadmin_dir != cur_tnsadmin_dir)
          begin
            reg['TNS_ADMIN'] = new_tnsadmin_dir
            Puppet.debug("Setting of TNS_ADMIN value in registry succcessful")

          rescue Exception => e
            fail("Setting up of TNS_ADMIN value in registry failed, Error: #{e.message}")
          end
        else
          Puppet.debug("Registry already has correct TNS_ADMIN value")
        end
      end
    rescue Exception => e
      fail("Unable to access the windows registry, Error: #{e.message}")
    end
  end

  def get_registry_value(env_key, throw_error = false)
    if Facter.value(:osfamily) != 'windows'
      Puppet.debug("Not a Windows platform, nothing to get")
    end
    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open("SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment") do |reg|
        begin
          cur_tnsadmin_dir = reg[env_key]
          return cur_tnsadmin_dir

        rescue Exception => e
          if throw_error
          fail("Getting of TNS_ADMIN value from registry failed, Error: #{e.message}")
          else
            return nil
          end
        end
      end
    rescue Exception => e
      fail("Unable to access the windows registry, Error: #{e.message}")
    end
  end

  def set_user_env()
    if Facter.value(:osfamily) != 'windows'
      Puppet.debug("Not a Windows platform, nothing to set")
    end
    cur_tnsadmin_dir = get_registry_value('TNS_ADMIN', false)
    if cur_tnsadmin_dir.nil? == false
      ENV['TNS_ADMIN'] = cur_tnsadmin_dir
    end

    path_value = get_registry_value('Path', true)
    ENV['PATH'] = path_value

    ps_home_dir = get_registry_value('PS_HOME', false)
    if ps_home_dir.nil? == false
      ENV['PS_HOME'] = ps_home_dir
    end
    ps_cfg_home_dir = get_registry_value('PS_CFG_HOME', false)
    if ps_cfg_home_dir.nil? == false
      ENV['PS_CFG_HOME'] = ps_cfg_home_dir
    end
    ps_app_home_dir = get_registry_value('PS_APP_HOME', false)
    if ps_app_home_dir.nil? == false
      ENV['PS_APP_HOME'] = ps_app_home_dir
    end
    ps_cust_home_dir = get_registry_value('PS_CUST_HOME', false)
    if ps_cust_home_dir.nil? == false
      ENV['PS_CUST_HOME'] = ps_app_home_dir
    end
  end

  private

  def sql_command_file(content)
    Puppet.debug("SQL Script content: #{content}")

    temp_dir_name = Dir.tmpdir()
    rand_num = rand(1000)
    command_file_path = File.join(temp_dir_name, "sql_cmd-#{rand_num}.sql")
    command_file = File.open(command_file_path, 'w')

    if Facter.value(:osfamily) == 'windows'
      #perm_cmd = "icacls #{command_file_path} /grant Administrators:F /T > NUL"
      perm_cmd = "icacls #{command_file_path} /grant *S-1-5-32-544:F /T > NUL"
      system(perm_cmd)
    else
      FileUtils.chmod(0755, command_file_path)
    end
    command_file.write(content)
    command_file.close
    return command_file_path
  end
 end
end

