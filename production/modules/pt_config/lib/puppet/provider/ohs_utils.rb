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

class OHSUtils

  def self.stop_domain(os_user, domain_name, domain_home_dir, webserver_hash)

    Puppet.debug("Stopping domain: #{domain_name}")

    # stop the domain instance first
    begin
      domain_home_path = File.join(domain_home_dir, 'webserv', domain_name)
      domain_cmd_dir = File.join(domain_home_path, 'bin')

      ohs_instance_name = 'ohs1'
      wlst_stop_log_file = File.join(webserver_hash[:webserver_home], 'logs', 'wlst_stop.log')
      if Facter.value(:osfamily) == 'windows'
        env_settings = "set WLST_PROPERTIES=\"-Dwlst.offline.log=#{wlst_stop_log_file}\" && "
        stop_cmd_path = File.join(domain_cmd_dir, 'stopComponent.cmd')
        stop_cmd = "#{env_settings} #{stop_cmd_path} #{ohs_instance_name}"
        Puppet.debug("OHS domain instance stop command: #{stop_cmd}")
      else
        admin_pwd = "#{webserver_hash[:webserver_admin_user_pwd]}"
        env_settings = "export WLST_PROPERTIES=\"-Dwlst.offline.log=#{wlst_stop_log_file}\" && "
        stop_cmd_path = File.join(domain_cmd_dir, 'stopComponent.sh')
        stop_cmd = "su - #{os_user} -c \"#{env_settings} echo #{admin_pwd} | #{stop_cmd_path} #{ohs_instance_name}\""
        Puppet.debug("OHS domain instance stop command: #{stop_cmd}".gsub(admin_pwd, '****'))
      end

      Puppet::Util::Execution.execute(stop_cmd, :failonfail => true)

    rescue Puppet::ExecutionFailure => e
      if (e.message.include?('is not currently running') == false) &&
         (e.message.include?('Connection refused') == false)
        raise Puppet::ExecutionFailure, "Unable to stop OHS domain #{domain_name} instance: #{e.message}"
      else
        Puppet.debug("Domain #{domain_name} already stopped")
      end
    end
    # stop the node manager
    if Facter.value(:osfamily) == 'windows'
      Puppet.debug("TBD...")
    else
      nm_stop_script = Tempfile.new(['ohs-nm', '.sh'])

      nm_stop_script.puts("#!/bin/sh")
      nm_stop_script.puts()
      nm_stop_script.puts("nm_pid_list=$(pgrep -f weblogic.NodeManager)")
      nm_stop_script.puts()
      nm_stop_script.puts("for nm_pid in $nm_pid_list")
      nm_stop_script.puts("do")
      nm_stop_script.puts("  Checking if PID ${nm_pid} matches OHS NodeNanager")
      nm_stop_script.puts("  cat /proc/${nm_pid}/cmdline | grep -Eq #{domain_home_path}")
      nm_stop_script.puts("  if [ $? -eq 0 ]; then")
      nm_stop_script.puts("    echo \"Shutting down NodeManager with process id ${nm_pid}\"")
      nm_stop_script.puts("    kill -9 ${nm_pid}")
      nm_stop_script.puts("    break")
      nm_stop_script.puts("  fi")
      nm_stop_script.puts("done")
      nm_stop_script.close
      nm_stop_script_path = nm_stop_script.path
      File.chmod(0755, nm_stop_script_path)
      Puppet.debug(File.read(nm_stop_script_path))

      begin
        stop_nm_cmd = "sh #{nm_stop_script_path}"
        command_output = Puppet::Util::Execution.execute(stop_nm_cmd, :failonfail => true)
        Puppet.debug("NodeManager shutdown command output: #{command_output}")
      rescue Puppet::ExecutionFailure => e
        raise Puppet::ExecutionFailure, "Unable to stop OHS node manager: #{e.message}"
      end
    end
  end

  def self.start_domain(os_user, domain_name, domain_home_dir, node_manager_port, webserver_hash, first_boot = false)
    Puppet.debug("Starting domain: #{domain_name}")

    domain_home_path = File.join(domain_home_dir, 'webserv', domain_name)
    domain_cmd_dir = File.join(domain_home_path, 'bin')

    # start the node manager first
    begin
      if Facter.value(:osfamily) == 'windows'
        start_cmd_path = File.join(domain_cmd_dir, 'startNodeManager.cmd')
        start_cmd = "start \"\" /b #{start_cmd_path}"
      else
        start_cmd_path = File.join(domain_cmd_dir, 'startNodeManager.sh')

        nm_start_log = File.join(webserver_hash[:webserver_home], 'logs', 'nm_start.log')
        system("su - #{os_user} -c \"touch #{nm_start_log} && chmod 755 #{nm_start_log}\"")

        nm_nohup_cmd = "nohup #{start_cmd_path} > #{nm_start_log} 2>&1 </dev/null &"
        start_cmd = "su - #{os_user} -c \"#{nm_nohup_cmd}\""
      end
      Puppet.debug("OHS node manager start command: #{start_cmd}")
      Puppet::Util::Execution.execute(start_cmd, :failonfail => true)

      if Facter.value(:osfamily) != 'windows'
        nm_started_msg = "Secure socket listener started on port"
        nm_already_started_msg = "another NodeManager process is already running"
        nm_adress_inuse_msg = "java.net.BindException: Address already in use"

        count = 1
        status = 'UNKNOWN'
        while status != 'STARTED'
          # read the node manager start log file
          nm_start_log_content = File.read(nm_start_log)

          if nm_start_log_content.include?(nm_started_msg)
            status = 'STARTED'
          elsif nm_start_log_content.include?(nm_already_started_msg)
            status = 'STARTED'
          elsif nm_start_log_content.include?(nm_adress_inuse_msg)
            raise Puppet::ExecutionFailure, "Unable to start OHS node manager: #{nm_adress_inuse_msg}"
          else
            sleep(2)
            count += 1
            if count >= 50
              raise Puppet::ExecutionFailure, "Unable to start OHS node manager:  Error: Unknown"
            end
          end
        end
      end
    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Unable to start OHS node manager: #{e.message}"
    end
    Puppet.debug("Node manager started successfully")

    # start the OHS domain instance
    begin
      ohs_instance_name = 'ohs1'
      admin_pwd = "#{webserver_hash[:webserver_admin_user_pwd]}"

      wlst_start_log_file = File.join(webserver_hash[:webserver_home], 'logs', 'wlst_start.log')
      if Facter.value(:osfamily) == 'windows'
        env_settings = "set WLST_PROPERTIES=\"-Dwlst.offline.log=#{wlst_start_log_file}\" && "
        start_cmd_path = File.join(domain_cmd_dir, 'startComponent.cmd')

        if first_boot == true
          start_cmd = "echo #{admin_pwd} | #{start_cmd_path} #{ohs_instance_name} storeUserConfig"
        else
          start_cmd = "#{env_settings} #{start_cmd_path} #{ohs_instance_name}"
        end
      else
        env_settings = "export WLST_PROPERTIES=\"-Dwlst.offline.log=#{wlst_start_log_file}\" && "
        start_cmd_path = File.join(domain_cmd_dir, 'startComponent.sh')

        if first_boot == true
          start_cmd = "su - #{os_user} -c \"echo #{admin_pwd} | #{start_cmd_path} #{ohs_instance_name} storeUserConfig\""
          Puppet.debug("OHS domain instance start command: #{start_cmd}".gsub(admin_pwd, '****'))
        else
          start_cmd = "su - #{os_user} -c \"#{env_settings} #{start_cmd_path} #{ohs_instance_name}\""
          Puppet.debug("OHS domain instance start command: #{start_cmd}")
        end
      end

      Puppet::Util::Execution.execute(start_cmd, :failonfail => true)

      domain_status = check_domain_status(os_user, domain_name, node_manager_port, webserver_hash)
      Puppet.debug("Domain #{domain_name} status is #{domain_status}")

    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Unable to start OHS domain instance: #{e.message}"
    end
  end

  def self.check_domain_status(os_user, domain_name, node_manager_port, webserver_hash)
    begin
      command_output = run_nm_command('nmServerStatus', os_user, domain_name,
                                      node_manager_port, webserver_hash)
      if command_output.include?('RUNNING')
        domain_status = 'running'
      else
        domain_status = 'stopped'
      end

    rescue Puppet::ExecutionFailure => e
      if e.message.include?('Connection refused')
        domain_status = 'stopped'
      else
        raise Puppet::ExecutionFailure, "OHS domain status check failed: #{e.message}"
      end
    end
    Puppet.debug("Domain #{domain_name} status #{domain_status}")
    return domain_status
  end

  def self.run_nm_command(nm_command, os_user, domain_name, node_manager_port, webserver_hash)

    Puppet.debug("Running Node Manager command #{nm_command} for domain: #{domain_name}")

    wlst_file = Tempfile.new(['ohs-nm-cmd', '.py'])

    wlst_file.puts("import os")
    wlst_file.puts()
    wlst_file.puts("domain_name = '#{domain_name}'")
    wlst_file.puts()
    wlst_file.puts("admin_user = '#{webserver_hash[:webserver_admin_user]}'")
    wlst_file.puts("admin_password = '#{webserver_hash[:webserver_admin_user_pwd]}'")
    wlst_file.puts("node_manager_port = #{node_manager_port}")

    wlst_file.puts()
    wlst_file.puts("nmConnect(admin_user, admin_password, 'localhost',")
    wlst_file.puts("          node_manager_port, domain_name)")
    wlst_file.puts()
    wlst_file.puts("#{nm_command}(serverName='ohs1', serverType='OHS')")
    wlst_file.puts("exit()")
    wlst_file.close
    wlst_file_path = wlst_file.path
    File.chmod(0755, wlst_file_path)
    Puppet.debug(" with response: #{File.read(wlst_file_path)}".gsub(webserver_hash[:webserver_admin_user_pwd], '****'))

    wlst_cmd_log_file = File.join(webserver_hash[:webserver_home], 'logs', "wlst_#{nm_command}.log")
    wlst_cmd_dir = File.join(webserver_hash[:webserver_home], 'ohs', 'common', 'bin')
    if Facter.value(:osfamily) == 'windows'
      env_settings = "set WLST_PROPERTIES=\"-Dwlst.offline.log=#{wlst_cmd_log_file}\" && "
      nm_cmd_path = File.join(wlst_cmd_dir, 'wlst.cmd')
      nm_cmd = "#{env_settings} #{nm_cmd_path} #{wlst_file_path}"
    else
      env_settings = "export WLST_PROPERTIES=\"-Dwlst.offline.log=#{wlst_cmd_log_file}\" && "
      nm_cmd_path = File.join(wlst_cmd_dir, 'wlst.sh')
      nm_cmd = "su - #{os_user} -c \"#{env_settings} #{nm_cmd_path} #{wlst_file_path}\""
    end
    begin
      command_output = Puppet::Util::Execution.execute(nm_cmd, :failonfail => true)
      Puppet.debug("Node Manager command output: #{command_output}")
      return command_output

    rescue Puppet::ExecutionFailure => e
      Puppet.debug("NodeManager command error: #{e.message}")
      raise e
    end
  end
end
