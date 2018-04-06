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
require 'open3'

require 'pt_comp_utils/validations'
require 'pt_comp_utils/database'
require 'puppet/provider/pt_utils'

class Puppet::Provider::Psae < Puppet::Provider
  include ::PtCompUtils::Validations
  include ::PtCompUtils::Database

    @db_hash = {}

    def run_ae()
      output = nil
      status = nil

      env_file_path, cfg_file_path = setup_environment()

      key_db_type        = :db_type
      db_type            = "#{@db_hash[key_db_type]}"
      if db_type == 'MSSQL'
        db_type = 'MICROSFT'
      end

      case Facter.value(:osfamily)
      when 'windows'
        insert_quote = ''
        ae_cmd_prefix = "#{env_file_path}"
        ae_cmd = File.join(resource[:ps_home_dir],
                           'bin', 'client', 'winx86', 'psae')
          set_user_env()
      when 'AIX'
        insert_quote = "\""
        ae_cmd_prefix = "su - #{resource[:os_user]} -c #{insert_quote}. #{env_file_path} "
        ae_cmd = File.join(resource[:ps_home_dir], 'bin', 'psae')
      when 'Solaris'
        insert_quote = "\""
        ae_cmd_prefix = "su - #{resource[:os_user]} -c #{insert_quote}. #{env_file_path} "
        ae_cmd = File.join(resource[:ps_home_dir], 'bin', 'psae')
      else
        insert_quote = "\""
        ae_cmd_prefix = "su -s /bin/bash - #{resource[:os_user]} -c #{insert_quote}. #{env_file_path} "
        ae_cmd = File.join(resource[:ps_home_dir], 'bin', 'psae')
      end

      key_db_name        = :db_name
      key_db_type        = :db_type
      key_db_opr_id      = :db_opr_id
      key_db_opr_pwd     = :db_opr_pwd
      key_db_server_name = :db_server_name

      ae_program_name="PTEM_CONFIG"
      ae_args = "-CT #{db_type} -CD #{@db_hash[key_db_name]} -CO #{@db_hash[key_db_opr_id]} -CP #{@db_hash[key_db_opr_pwd]} -R #{resource[:run_control_id].to_s} -AI #{ae_program_name} -I #{resource[:process_instance].to_s}"

      db_server_name = @db_hash[key_db_server_name]
      if !db_server_name.nil?
        ae_args << " -CS #{db_server_name}"
      end

      ae_cmd_file = create_ae_cmd_file(ae_args)

      ae_full_cmd = "#{ae_cmd_prefix} && #{ae_cmd} #{ae_cmd_file} #{insert_quote}"
      #ae_full_cmd = "#{ae_cmd_prefix} && #{ae_cmd} #{ae_args} #{insert_quote}"

      Puppet.debug("PSAE Command: #{ae_full_cmd}")

      output = ''
      exit_status = 0
      begin
        if Facter.value(:osfamily) == 'windows'
          output = execute_command(ae_full_cmd)
        else
          output = Puppet::Util::Execution.execute(ae_full_cmd, :failonfail => true, :combine => true)
        end
        if output.include?('STATUS: ERROR') || output.include?('failed: No such file or directory')
          exit_status = 1
        end

      rescue Puppet::ExecutionFailure => e
        Puppet.debug("Executing of AE failed: #{e.message}")
        exit_status = 1
        output = "#{output}, #{e.message}"
      ensure
        FileUtils.remove_file(cfg_file_path, :force => true)
        FileUtils.remove_file(env_file_path, :force => true)
        FileUtils.remove_file(ae_cmd_file, :force => true)
      end

      return output, exit_status
    end

    def db_hash=(db_hash)
      @db_hash = db_hash
    end

    def self.instances
      []
    end

    private

    def create_ae_cmd_file(ae_parameters)
      # genenrate the ae file with the details
      temp_dir_name = Dir.tmpdir
      rand_num = rand(1000)
      file_prop_path = File.join(temp_dir_name, "temp_ae_cmd_#{rand_num}.txt")
      file_prop = File.open(file_prop_path, 'w')
      file_prop.puts ae_parameters
      file_prop.close
      File.chmod(0755, file_prop_path)
      return file_prop_path
    end

    def setup_environment()
      temp_dir_name = Dir.tmpdir()

      key_db_connect_id  = :db_connect_id
      key_db_connect_pwd = :db_connect_pwd

      cfg_file_path = File.join(temp_dir_name, "ae-conn.cfg")
      file_cfg = File.open(cfg_file_path, 'w')
      file_cfg.puts "[Startup]"
      file_cfg.puts "ConnectId=" + @db_hash[key_db_connect_id]
      file_cfg.puts "ConnectPswd=" + @db_hash[key_db_connect_pwd]
      file_cfg.close
      File.chmod(0755, cfg_file_path)
      if File.exist?(cfg_file_path)
        Puppet.debug("Connection file #{cfg_file_path} is present")
      else
        Puppet.debug("Connection file #{cfg_file_path} is absent")
      end
      Puppet.debug(File.read(cfg_file_path).gsub @db_hash[key_db_connect_pwd], '****')

      case Facter.value(:osfamily)
      when 'windows'
        env_prefix = 'set'
        file_ext = '.bat'
      else
        env_prefix = 'export'
        file_ext = '.sh'
      end
      rand_num = rand(1000)
      env_file_path = File.join(temp_dir_name, "ae-env-#{rand_num}#{file_ext}")
      file_env = File.open(env_file_path, 'w')

      file_env.puts "#{env_prefix} PS_SERVER_CFG=#{cfg_file_path}"
      file_env.puts "#{env_prefix} PS_SERVERDIR=#{temp_dir_name}"
      file_env.close
      File.chmod(0755, env_file_path)
      if File.exist?(env_file_path)
        Puppet.debug("Env file #{env_file_path} is present")
      else
        Puppet.debug("Env file #{env_file_path} is absent")
      end
      Puppet.debug(File.read(env_file_path))

      return env_file_path, cfg_file_path
    end
end
