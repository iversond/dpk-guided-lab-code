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

require 'puppet/provider/psftdomainboot'
require 'easy_type'

if Facter.value(:osfamily) == 'windows'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_appserver_domain_boot).provide :appserver_domain_boot,
                  :parent => Puppet::Provider::PsftDomainBoot do
  include EasyType::Template

  desc "The Application Server domain boot provider."

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  def stop_domain
    Puppet.debug("Action appserver domain stop called")

    # call the base call method
    super()

    if Facter.value(:osfamily) == 'windows'
      domain_name = resource[:domain_name]

      appserver_domain_service = "PsftAppServerDomain#{domain_name}Service"
      begin
        # stop the windows service
        Service.stop(appserver_domain_service)
      rescue Exception => e
        Puppet.debug("Error while stopping windows Service #{appserver_domain_service}: #{e.message}")
        system("sc stop #{appserver_domain_service} > NUL")
      end
      begin
        # delete the windows service
        Service.delete(appserver_domain_service)
      rescue Exception => e
        Puppet.debug("Error while deleting windows Service #{appserver_domain_service}: #{e.message}")
        system("sc delete #{appserver_domain_service} > NUL")
      end
    end
  end

  def start_domain
    Puppet.debug("Action appserver domain start called")

    # call the base call method
    super()

    if Facter.value(:osfamily) == 'windows'
      domain_name = resource[:domain_name]
      ps_cfg_home = resource[:ps_cfg_home_dir]
      ps_home     = resource[:ps_home_dir]

      appserver_win_service_file = File.join(ps_cfg_home, 'appserv', domain_name, "appserver_win_service.rb")
      appserver_win_service_content = template('puppet:///modules/pt_config/pt_appserver/appserver_win_service.rb.erb',
                                               binding)
      appserver_win_service_content = appserver_win_service_content.gsub('/', '//')
      appserver_win_service_content = appserver_win_service_content.gsub('/', '\\')
      File.open(appserver_win_service_file, 'w') { |f| f.write("#{appserver_win_service_content}") }

      appserver_win_service_file = appserver_win_service_file.gsub('/', '\\')
      ruby_executable = File.join(RbConfig::CONFIG['bindir'],
                                  RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'])
      ruby_executable_temp = ruby_executable.gsub('/', '\\')
      cmd_short_path = "for %A in (\"#{ruby_executable_temp}\") do @echo %~sA"
      ruby_executable = `#{cmd_short_path}`
      Puppet.debug("Ruby executable path: #{ruby_executable}")

      appserver_domain_service = "PsftAppServerDomain#{domain_name}Service"
      begin
        # setup the service
        Puppet.debug("Creating AppServer domain service #{appserver_domain_service}")
        Service.create({
          :service_name     => appserver_domain_service,
          :host             => nil,
          :service_type     => Service::WIN32_OWN_PROCESS,
          :description      => "PeopleSoft AppServer Domain #{domain_name} Service",
          :start_type       => Service::SERVICE_AUTO_START,
          :error_control    => Service::ERROR_NORMAL,
          :binary_path_name => "#{ruby_executable.chomp} #{appserver_win_service_file}",
          :load_order_group => 'Network',
          :dependencies     => nil,
          :display_name     => appserver_domain_service
        })
      rescue Exception => e
        if (e.message.include?('The specified service already exists') ||
            e.message.include?('An instance of the service is already running'))
          begin
            # stop the windows service
            Puppet.debug("AppServer domain service #{appserver_domain_service} exists, stopping it")
            service.stop(appserver_domain_service)
          rescue Exception => e
            Puppet.debug("Error while stopping windows Service #{appserver_domain_service}: #{e.message}")
          end
        else
          raise Puppet::ExecutionFailure, "Unable to start domain #{domain_name}: #{e.message}"
        end
      end
      begin
        Puppet.debug("Starting AppServer Domain service: #{appserver_domain_service}")
        Service.start(appserver_domain_service)
      rescue Puppet::ExecutionFailure => e
        raise Puppet::ExecutionFailure, "Unable to start appserver domain #{domain_name}: #{e.message}"
      rescue Exception => e
        raise Puppet::ExecutionFailure, "Unable to start appserver domain #{domain_name}: #{e.message}"
      end
    end
  end

  private

  def get_domain_type
    return "-c"
  end
end
