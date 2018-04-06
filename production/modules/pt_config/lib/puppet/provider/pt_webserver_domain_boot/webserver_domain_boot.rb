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

require 'puppet/provider/pt_utils'
require 'pt_comp_utils/validations'
require 'pt_comp_utils/webserver'
require 'easy_type'

if Facter.value(:osfamily) == 'windows'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_webserver_domain_boot).provide :webserver_domain_boot do
  include EasyType::Template
  include ::PtCompUtils::Validations
  include ::PtCompUtils::WebServer

  desc "The PIA domain boot provider."

  mk_resource_methods

  def self.instance
    []
  end

  @webserver_hash = {}

  def webserver_hash=(webserver_hash)
    Puppet.debug("Caching Webserver settings")
    @webserver_hash = webserver_hash
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
    return get_domain_status()
  end

  def get_domain_status

    domain_name = resource[:domain_name]
    ps_cfg_home = resource[:ps_cfg_home_dir]
    domain_dir = File.join(ps_cfg_home, 'webserv', domain_name, 'bin')

    Puppet.debug("Getting status of domain: #{domain_name}")

    # check the status of the domain first
    domain_status = :running
    if Facter.value(:osfamily) == 'windows'
      status_cmd = File.join(domain_dir, 'singleserverStatus.cmd')
    else
      os_user = resource[:os_user]
      if os_user_exists?(os_user) == false
        domain_status = :stopped
        return domain_status
      end
      status_cmd_path = File.join(domain_dir, 'singleserverStatus.sh')
      status_cmd = "su - #{os_user} -c \"#{status_cmd_path}\""
    end
    begin
      Puppet.debug("Webserver status command: #{status_cmd}")
      if Facter.value(:osfamily) != 'windows'
        status_msg = Puppet::Util::Execution.execute(status_cmd, :failonfail => true, :combine => true)
      else
        status_msg = execute_command(status_cmd)
      end
      Puppet.debug("Webserver status: #{status_msg}")
      if status_msg.include?('Failed')
        Puppet.debug("Domain #{domain_name} already stopped")
        domain_status = :stopped
      end
      return domain_status

    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure,
              "Unable to get status of domain #{domain_name}: #{e.message}"
    end
  end


  def stop_domain
    domain_name = resource[:domain_name]
    ps_cfg_home = resource[:ps_cfg_home_dir]
    domain_dir = File.join(ps_cfg_home, 'webserv', domain_name, 'bin')

    Puppet.debug("Stopping domain: #{domain_name}")

    # stop the domain
    if Facter.value(:osfamily) == 'windows'
      stop_cmd = File.join(domain_dir, 'stopPIA.cmd')
    else
      stop_cmd_path = File.join(domain_dir, 'stopPIA.sh')
      stop_cmd = "su - #{resource[:os_user]} -c \"#{stop_cmd_path}\""
    end

    begin
      Puppet.debug("Webserver stopping command: #{stop_cmd}")
      Puppet::Util::Execution.execute(stop_cmd, :failonfail => true)

    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Unable to stop domain #{domain_name}: #{e.message}"
    end

    if Facter.value(:osfamily) == 'windows'
      pia_domain_service = "PsftPIADomain#{domain_name}Service"
      begin
        # stop the windows service
        Service.stop(pia_domain_service)
      rescue Exception => e
        Puppet.debug("Error while stopping windows Service #{pia_domain_service}: #{e.message}")
        system("sc stop #{pia_domain_service} > NUL")
      end
      begin
        Service.delete(pia_domain_service)
      rescue Exception => e
        Puppet.debug("Error while deleting windows Service #{pia_domain_service}: #{e.message}")
        system("sc delete #{pia_domain_service} > NUL")
      end
    end
  end

  def start_domain
    domain_name = resource[:domain_name]
    ps_cfg_home = resource[:ps_cfg_home_dir]
    domain_dir = File.join(ps_cfg_home, 'webserv', domain_name, 'bin')

    Puppet.debug("Starting domain: #{domain_name}")

      # start the domain
      if Facter.value(:osfamily) == 'windows'
      pia_win_service_file = File.join(ps_cfg_home, 'webserv', domain_name, "pia_win_service.rb")
      pia_win_service_content = template('puppet:///modules/pt_config/pt_pia/pia_win_service.rb.erb',
                                         binding)
      pia_win_service_content = pia_win_service_content.gsub('/', '//')
      pia_win_service_content = pia_win_service_content.gsub('/', '\\')
      File.open(pia_win_service_file, 'w') { |f| f.write("#{pia_win_service_content}") }

      pia_win_service_file = pia_win_service_file.gsub('/', '\\')
      ruby_executable = File.join(RbConfig::CONFIG['bindir'],
                                  RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'])
      ruby_executable_temp = ruby_executable.gsub('/', '\\')
      cmd_short_path = "for %A in (\"#{ruby_executable_temp}\") do @echo %~sA"
      ruby_executable = `#{cmd_short_path}`
      Puppet.debug("Ruby executable path: #{ruby_executable}")

      pia_domain_service = "PsftPIADomain#{domain_name}Service"
      begin
        # setup the service
        Puppet.debug("Creating PIA domain service #{pia_domain_service}")
        Service.create({
          :service_name     => pia_domain_service,
          :host             => nil,
          :service_type     => Service::WIN32_OWN_PROCESS,
          :description      => "PeopleSoft PIA Domain #{domain_name} Service",
          :start_type       => Service::SERVICE_AUTO_START,
          :error_control    => Service::ERROR_NORMAL,
          :binary_path_name => "#{ruby_executable.chomp} #{pia_win_service_file}",
          :load_order_group => 'Network',
          :dependencies     => nil,
          :display_name     => pia_domain_service
        })
      rescue Exception => e
        if (e.message.include?('The specified service already exists') ||
            e.message.include?('An instance of the service is already running'))
          begin
            # stop the windows service
            Puppet.debug("PIA domain service #{pia_domain_service} exists, stopping it")
            Service.stop("#{pia_domain_service}")
          rescue Exception => e
            Puppet.debug("Error while stopping windows Service #{pia_domain_service}: #{e.message}")
          end
        else
          raise Puppet::ExecutionFailure, "Unable to start domain #{domain_name}: #{e.message}"
        end
      end
      else
        os_user = resource[:os_user]
        start_cmd_path = File.join(domain_dir, 'startPIA.sh')
        start_cmd = "su - #{os_user} -c \"#{start_cmd_path}\""
    end

    begin
      if Facter.value(:osfamily) == 'windows'
        pia_domain_service = "PsftPIADomain#{domain_name}Service"
        Puppet.debug("Starting PIA Domain service: #{pia_domain_service}")
        Service.start(pia_domain_service)
      else
        Puppet::Util::Execution.execute(start_cmd, :failonfail => true)
      end
      bea_home   = "#{@webserver_hash[:webserver_home]}"
      admin_user = "#{@webserver_hash[:webserver_admin_user]}"
      admin_pwd  = "#{@webserver_hash[:webserver_admin_user_pwd]}"
      http_port  = "#{@webserver_hash[:webserver_http_port].to_s}"

      if is_weblogic_server_running?(os_user, bea_home, http_port,
                                     admin_user, admin_pwd, "PIA") == false
        raise Puppet::ExecutionFailure, "Unable to get the status of domain #{domain_name}"
      end

    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Unable to start domain #{domain_name}: #{e.message}"
    rescue Exception => e
      raise Puppet::ExecutionFailure, "Unable to start domain #{domain_name}: #{e.message}"
    end
  end
end
