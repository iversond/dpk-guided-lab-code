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
require 'fileutils'
require 'tempfile'
require 'pt_comp_utils/webserver'
require 'puppet/provider/pt_utils'

class Puppet::Provider::WebAppDomain < Puppet::Provider
  include ::PtCompUtils::WebServer

  @webserver_hash = {}

  def initialize(value={})
    super(value)
    Puppet.debug("Provider Initialization")
    @property_flush = {}
  end

  def webserver_hash=(webserver_hash)
    Puppet.debug("Caching Webserver settings")
    @webserver_hash = webserver_hash
  end

  def exists?
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end

    domain_name = resource[:domain_name]
    webapp_dir = resource[:webapp_dir]
    domain_exists = check_webserver_domain_exists?(webapp_dir, domain_name)
    if domain_exists == true 
      @property_hash[:ensure] = :present
      Puppet.debug("Resource exists")
      true
    else
      @property_hash[:ensure] = :absent
      Puppet.debug("Resource does not exists")
      false
    end
  end

  def create
    pre_create()

    domain_name = resource[:domain_name]

    response_file = get_response_file()
    Puppet.debug("Using response file #{response_file}")

    Puppet.debug("Creating domain: #{domain_name}")

    begin
      install_dir = File.join(resource[:ps_home_dir], 'setup', 'PsMpWebAppDeployInstall')
      if Facter.value(:osfamily) == 'windows'
        install_cmd = File.join(install_dir, 'setup.bat')

        command = "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}"
        execute_command(command)
      elsif Facter.value(:osfamily) == 'Solaris'
        install_cmd = File.join(install_dir, 'setup.sh')
        domain_cmd('-', resource[:os_user], '-c',
                   "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
      elsif Facter.value(:kernel) == 'Linux'
        install_cmd = File.join(install_dir, 'setup.sh')
        domain_cmd('-m', '-s', '/bin/bash', '-l',  resource[:os_user], '-c',
                   "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
      elsif Facter.value(:kernel) == 'AIX'
        install_cmd = File.join(install_dir, 'setup.sh')
        domain_cmd('-', resource[:os_user], '-c',
                   "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
      end

      post_create()
      @property_hash[:ensure] = :present

    rescue Puppet::ExecutionFailure => e
        raise Puppet::Error,
          "Unable to create WebApp Deploy domain #{domain_name}: #{e.message}"
    end
  end


  def destroy
    stop_domain()

    # remove the domain directory
    domain_dir = File.join(resource[:webapp_dir], 'webserv',
                           resource[:domain_name])
    FileUtils.rm_rf(domain_dir)

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
    @property_hash = resource.to_hash
  end

  def self.instances
    []
  end

  private

  def pre_create
    # make sure the  ps_cfg_home_dir is given
    if resource[:ps_cfg_home_dir].nil?
      raise ArgumentError, "PS_CFG_HOME home directory needs to be " +
                           "specified to create a WebServer domain"
    end
    #
    # make sure WebServer settings are given
    if @webserver_hash.nil? || @webserver_hash.size == 0
      raise ArgumentError, "webserver_settings needs to be specified " +
                           " to create a Web Application deployment domain"
    end
  end

  def post_create
    domain_name = resource[:domain_name]
    Puppet.debug("Post create domain: #{domain_name}")

    configure_domain()
    start_domain()
  end

  def configure_domain
    @property_flush.clear
  end

  def stop_domain
    domain_name = resource[:domain_name]

    Puppet.debug("Stopping domain: #{domain_name}")

    domain_dir = File.join(resource[:webapp_dir], 'webserv', domain_name, 'bin')
    begin
      if Facter.value(:osfamily) == 'windows'
        stop_cmd = File.join(domain_dir, 'stopWebLogic.bat')
        command = stop_cmd
        execute_command(command)
      elsif Facter.value(:osfamily) == 'Solaris'
        stop_cmd = File.join(domain_dir, 'stopWebLogic.sh')
        domain_cmd('-',  resource[:os_user], '-c', "#{stop_cmd}")
      elsif Facter.value(:kernel) == 'Linux'
        stop_cmd = File.join(domain_dir, 'stopWebLogic.sh')
        domain_cmd('-m', '-s', '/bin/bash', '-l',  resource[:os_user], '-c', "#{stop_cmd}")
      elsif Facter.value(:kernel) == 'AIX'
        stop_cmd = File.join(domain_dir, 'stopWebLogic.sh')
        domain_cmd('-',  resource[:os_user], '-c', "#{stop_cmd}")
      end

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error,
          "Unable to stop domain #{domain_name}: #{e.message}"
    end
  end

  def start_domain
    domain_name = resource[:domain_name]

    Puppet.debug("Starting domain: #{domain_name}")

    domain_dir = File.join(resource[:webapp_dir], 'webserv', domain_name, 'bin')
    begin
      if Facter.value(:osfamily) == 'windows'
        start_cmd = File.join(domain_dir, 'startWebLogic.bat')
        command = start_cmd
        execute_command(command)
      elsif Facter.value(:osfamily) == 'Solaris'
        start_cmd = File.join(domain_dir, 'startWebLogic.sh')
        domain_cmd('-',  resource[:os_user], '-c', "#{start_cmd}")
      elsif Facter.value(:kernel) == 'Linux'
        start_cmd = File.join(domain_dir, 'startWebLogic.sh')
        domain_cmd('-m', '-s', '/bin/bash', '-l',  resource[:os_user], '-c', "#{start_cmd}")
      elsif Facter.value(:kernel) == 'AIX'
        start_cmd = File.join(domain_dir, 'startWebLogic.sh')
        domain_cmd('-',  resource[:os_user], '-c', "#{start_cmd}")
      end

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error,
          "Unable to start domain #{domain_name}: #{e.message}"
    end
  end

  # This function generates the response file (user inputs) to the WebAppDeploy
  # installation. This response file is used by the WebAppDeploy to run in a
  #  silent mode
  def get_response_file
    domain_name = resource[:domain_name]

    response_file = Tempfile.new('webapp-response')
    response_file.puts('SERVER_TYPE=' + @webserver_hash[:webserver_type])
    response_file.puts('DOMAIN_NAME=' + domain_name)
    response_file.puts('DOMAIN_TYPE=NEW_DOMAIN')
    response_file.puts('INSTALL_ACTION=CREATE_NEW_DOMAIN')
    response_file.puts('INSTALL_TYPE=SINGLE_SERVER_INSTALLATION')

    response_file.puts('PS_CFG_HOME=' + resource[:webapp_dir])
    response_file.puts('BEA_HOME=' + @webserver_hash[:webserver_home])
    response_file.puts('USER_ID=' + @webserver_hash[:webserver_admin_user])
    webserver_admin_pwd = @webserver_hash[:webserver_admin_pwd]

    response_file.puts('USER_PWD=' + webserver_admin_pwd)
    response_file.puts('USER_PWD_RETYPE=' + webserver_admin_pwd)
    response_file.puts('DEPLOY_TYPE=' + resource[:deployment_type].to_s)
    response_file.puts('HTTP_PORT=' + resource[:http_port].to_s)
    response_file.puts('HTTPS_PORT=' + resource[:https_port].to_s)
    response_file.puts('PS_APP_HOME=' + resource[:ps_app_home_dir])

    response_file.close
    response_file_path = response_file.path
    File.chmod(0755, response_file_path)

    return response_file_path
  end
end
