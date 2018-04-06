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

Puppet::Type.type(:pt_prcs_domain_boot).provide :prcs_domain_boot,
                  :parent => Puppet::Provider::PsftDomainBoot do
  include EasyType::Template

  desc "The Process Scheduler domain boot provider."

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  def stop_domain
    Puppet.debug("Action prcs domain stop called")

    # call the base call method
    super()

    if Facter.value(:osfamily) == 'windows'
      domain_name = resource[:domain_name]

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

  def start_domain
    Puppet.debug("Action prcs domain start called")

    # call the base call method
    super()

    if Facter.value(:osfamily) == 'windows'
      domain_name = resource[:domain_name]
      ps_cfg_home = resource[:ps_cfg_home_dir]
      ps_home     = resource[:ps_home_dir]

      prcs_win_service_file = File.join(ps_cfg_home, 'appserv', 'prcs', domain_name, "prcs_win_service.rb")
      prcs_win_service_content = template('puppet:///modules/pt_config/pt_prcs/prcs_win_service.rb.erb',
                                               binding)
      prcs_win_service_content = prcs_win_service_content.gsub('/', '//')
      prcs_win_service_content = prcs_win_service_content.gsub('/', '\\')
      File.open(prcs_win_service_file, 'w') { |f| f.write("#{prcs_win_service_content}") }

      prcs_win_service_file = prcs_win_service_file.gsub('/', '\\')
      ruby_executable = File.join(RbConfig::CONFIG['bindir'],
                                  RbConfig::CONFIG['RUBY_INSTALL_NAME'] + RbConfig::CONFIG['EXEEXT'])
      ruby_executable_temp = ruby_executable.gsub('/', '\\')
      cmd_short_path = "for %A in (\"#{ruby_executable_temp}\") do @echo %~sA"
      ruby_executable = `#{cmd_short_path}`
      Puppet.debug("Ruby executable path: #{ruby_executable}")

      prcs_domain_service = "PsftPrcsDomain#{domain_name}Service"
      begin
        # setup the service
        Puppet.debug("Creating Prcs domain service #{prcs_domain_service}")
        Service.create({
          :service_name     => prcs_domain_service,
          :host             => nil,
          :service_type     => Service::WIN32_OWN_PROCESS,
          :description      => "PeopleSoft Prcs Domain #{domain_name} Service",
          :start_type       => Service::SERVICE_AUTO_START,
          :error_control    => Service::ERROR_NORMAL,
          :binary_path_name => "#{ruby_executable.chomp} #{prcs_win_service_file}",
          :load_order_group => 'Network',
          :dependencies     => nil,
          :display_name     => prcs_domain_service
        })
      rescue Exception => e
        if (e.message.include?('The specified service already exists') ||
            e.message.include?('An instance of the service is already running'))
          begin
            # stop the windows service
            Puppet.debug("Prcs domain service #{prcs_domain_service} exists, stopping it")
            service.stop(prcs_domain_service)
          rescue Exception => e
            Puppet.debug("Error while stopping windows Service #{prcs_domain_service}: #{e.message}")
          end
        else
          raise Puppet::ExecutionFailure, "Unable to start domain #{domain_name}: #{e.message}"
        end
      end
      begin
        Puppet.debug("Starting Prcs Domain service: #{prcs_domain_service}")
        Service.start(prcs_domain_service)
      rescue Puppet::ExecutionFailure => e
        raise Puppet::ExecutionFailure, "Unable to start prcs domain #{domain_name}: #{e.message}"
      rescue Exception => e
        raise Puppet::ExecutionFailure, "Unable to start prcs domain #{domain_name}: #{e.message}"
      end
    end
  end

  private

  def get_domain_type
    return "-p"
  end
end
