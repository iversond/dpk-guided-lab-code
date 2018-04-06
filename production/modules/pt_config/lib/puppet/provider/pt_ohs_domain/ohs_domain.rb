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

require 'pt_comp_utils/validations'
require 'pt_comp_utils/webserver'
require 'puppet/provider/pt_utils'
require 'puppet/provider/ohs_utils'

Puppet::Type.type(:pt_ohs_domain).provide :ohs_domain do
  include ::PtCompUtils::Validations
  include ::PtCompUtils::WebServer

  mk_resource_methods

  def pia_webserver_host=(value)
    @property_flush[:pia_webserver_host] = value
  end

  def pia_webserver_port=(value)
    @property_flush[:pia_webserver_port] = value
  end

  def pia_webserver_type=(value)
    @property_flush[:pia_webserver_type] = value
  end

  def initialize(value={})
    super(value)
    Puppet.debug("Provider Initialization")
    @property_flush = {}
  end

  @webserver_hash = {}

  def webserver_hash=(webserver_hash)
    Puppet.debug("Caching Webserver settings")
    @webserver_hash = webserver_hash
  end

  def exists?
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end

    domain_name = resource[:domain_name]
    domain_dir = resource[:domain_home_dir]

    domain_exists = check_webserver_domain_exists?(domain_dir, domain_name)
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
    domain_home_dir = resource[:domain_home_dir]
    domain_home_path = File.join(domain_home_dir, 'webserv', domain_name)

    wlst_file = construct_domain_creation_script()
    Puppet.debug("Creating domain: #{domain_name}")
    Puppet.debug(" with response: #{File.read(wlst_file)}")

    os_user = resource[:os_user]
    install_dir = File.join(@webserver_hash[:webserver_home], 'ohs',
                            'common', 'bin')
    if Facter.value(:osfamily) == 'windows'
      install_cmd_path = File.join(install_dir, 'wlst.cmd')
      install_cmd = "#{install_cmd} #{wlst_file}"
    else
      install_cmd_path = File.join(install_dir, 'wlst.sh')
      install_cmd = "su - #{os_user} -c \"#{install_cmd_path} #{wlst_file}\""
      end
    begin
      Puppet.debug("OHS domain creation command: #{install_cmd}")
      Puppet::Util::Execution.execute(install_cmd, :failonfail => true)

      File.chmod(0775, File.join(@webserver_hash[:webserver_home], 'logs'))

      # fix the config.xml of the domain
      # TODO: need to figure out why having the node-manager name tag
      # results in error
      config_file = File.join(domain_home_path, 'config', 'config.xml')
      domain_config_content = File.read(config_file)

      begin
        regexp = ".*<name>node-manager</name>.*\n"
        re = Regexp.compile(regexp)

      rescue RegexpError, TypeError
        raise(Puppet::ParseError, "Bad regular expression `#{regexp}'")
      end
      domain_config_content = domain_config_content.gsub(re, '')
      File.open(config_file, 'w') { |f| f.write(domain_config_content) }

      post_create()
      @property_hash[:ensure] = :present

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Unable to create OHS domain #{domain_name}: #{e.message}"
    end
  end

  def destroy
    # make sure the domain_home_dir and os_user exits
    domain_name = resource[:domain_name]
    domain_home_dir = resource[:domain_home_dir]
    if domain_home_dir.nil?
      raise ArgumentError, "Domain home directory needs to be " +
                           "specified to manage an OHS domain"
    end
    if Facter.value(:osfamily) != 'windows' and os_user.nil?
      fail("os_user attribute should be specified for managing " +
           "an OHS domain on Unix platforms")
    end

    if Facter.value(:osfamily) == 'windows'
      os_user = ''
    else
      os_user = resource[:os_user]
    end
    OHSUtils.stop_domain(os_user, domain_name, domain_home_dir, @webserver_hash)

    # remove the domain directory
    domain_full_path = File.join(domain_home_dir, 'webserv', domain_name)
    FileUtils.rm_rf(domain_full_path)

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

  def pre_create
    domain_name = resource[:domain_name]

    Puppet.debug("Pre Create domain: #{domain_name}")

    # validate to make sure all the required parameters are specified to
    # create a webserver domain
    # validate that the ports are no in use
    validate_port(resource[:node_manager_port])
    validate_port(@webserver_hash[:webserver_admin_port])
    validate_port(@webserver_hash[:webserver_http_port])
    validate_port(@webserver_hash[:webserver_https_port])

    # make sure the domain_home_dir and os_user exits
    domain_home_dir = resource[:domain_home_dir]
    os_user = resource[:os_user]
    validate_params_exists(os_user, domain_home_dir)
  end

  def post_create
    domain_name = resource[:domain_name]

    Puppet.debug("Post Create domain: #{domain_name}")

    restart_needed = false
    # flush to configure and start the domain
    # stick the properties into the flush hash and call configure
    if ! resource[:pia_webserver_host].nil?
      @property_flush[:pia_webserver_host] = resource[:pia_webserver_host]
      restart_needed = true
    end
    if ! resource[:pia_webserver_port].nil?
      @property_flush[:pia_webserver_port] = resource[:pia_webserver_port]
      restart_needed = true
    end
    if ! resource[:pia_webserver_type].nil?
      @property_flush[:pia_webserver_type] = resource[:pia_webserver_type]
    end

    start_domain(true)
    configure_domain()

    if restart_needed
      restart_domain()
    end

    domain_start = resource[:domain_start]
    if domain_start.to_s == "false"
      Puppet.debug("Domain start not requested")
      stop_domain()
    end
  end

  def configure_domain
    domain_name = resource[:domain_name]

    Puppet.debug("Configuring domain: #{domain_name}")
    if @property_flush.size == 0
      Puppet.debug("Nothing to configure")
      return
    end

    pia_webserver_type = resource[:pia_webserver_type]
    Puppet.debug("Configuring plugin for PIA WebServer type: #{pia_webserver_type.to_s}")
    if pia_webserver_type == :weblogic
      # modify wls plugin
      domain_full_path = File.join(resource[:domain_home_dir], 'webserv', domain_name)
      wl_plugin_file = File.join(domain_full_path, 'config', 'fmwconfig',
                                    'components', 'OHS', 'instances', 'ohs1',
                                    'mod_wl_ohs.conf')

      wl_plugin_content = File.read(wl_plugin_file)

      update_plugin_file = false
      pia_webserver_host = @property_flush[:pia_webserver_host]
      if pia_webserver_host.nil? == false
        Puppet.debug("Updating Weblogic Plugin with host: #{pia_webserver_host}")
        wl_plugin_content = wl_plugin_content.gsub(/.*MatchExpression.*/,
                                                   "   MatchExpression *")
        wl_plugin_content = wl_plugin_content.gsub(/.*WebLogicHost.*/,
                                                   "   WebLogicHost #{pia_webserver_host}")
        update_plugin_file = true
      end
      pia_webserver_port = @property_flush[:pia_webserver_port]
      if pia_webserver_port.nil? == false
        Puppet.debug("Updating Weblogic Plugin with port: #{pia_webserver_port}")
        wl_plugin_content = wl_plugin_content.gsub(/.*WebLogicPort.*/,
                                                   "   WebLogicPort #{pia_webserver_port}")
        update_plugin_file = true
      end
      if update_plugin_file == true
        Puppet.debug("Writing WL plugin content: #{wl_plugin_content}")
        File.open(wl_plugin_file, 'w') { |f| f.write(wl_plugin_content) }
      end
    end
    @property_flush.clear
  end

  # This function generates the OHS domain creation  WLST script
  def construct_domain_creation_script
    domain_home_dir = resource[:domain_home_dir]

    wlst_file = Tempfile.new(['ohs-domain-creation', '.py'])

    log_file = Tempfile.new('wlst-log')
    wlst_log_file = log_file.path
    File.chmod(0755, wlst_log_file)

    wlst_file.puts("import os")
    wlst_file.puts()
    wlst_file.puts("oracle_home = '#{@webserver_hash[:webserver_home]}'")
    wlst_file.puts("domain_name = '#{resource[:domain_name]}'")
    wlst_file.puts("domain_home_dir = '#{domain_home_dir}'")
    wlst_file.puts("node_manager_port = #{resource[:node_manager_port]}")
    wlst_file.puts()
    wlst_file.puts("admin_user = '#{@webserver_hash[:webserver_admin_user]}'")
    wlst_file.puts("admin_password = '#{@webserver_hash[:webserver_admin_user_pwd]}'")
    wlst_file.puts("admin_host = '#{Facter.value(:fqdn)}'")
    wlst_file.puts("admin_port = '#{@webserver_hash[:webserver_admin_port]}'")
    wlst_file.puts("listen_http_port = '#{@webserver_hash[:webserver_http_port]}'")
    wlst_file.puts("listen_https_port = '#{@webserver_hash[:webserver_https_port]}'")

    wlst_file.puts("domain_full_path = os.path.join(domain_home_dir, 'webserv', domain_name)")
    wlst_file.puts("ohs_domain_template_path = os.path.join(oracle_home, 'ohs',")
    wlst_file.puts("                              'common', 'templates', 'wls',")
    wlst_file.puts("                              'ohs_standalone_template.jar')")
    wlst_file.puts()
    wlst_file.puts("readTemplate(ohs_domain_template_path)")
    wlst_file.puts()
    wlst_file.puts("cd('/')")
    wlst_file.puts("cd('NMProperties')")
    wlst_file.puts("set('ListenAddress','localhost')")
    wlst_file.puts("set('ListenPort', node_manager_port)")
    wlst_file.puts("cd('/')")
    wlst_file.puts("create(domain_name, 'SecurityConfiguration')")
    wlst_file.puts()
    wlst_file.puts("cd('SecurityConfiguration/' + domain_name)")
    wlst_file.puts("set('NodeManagerUsername', admin_user)")
    wlst_file.puts("set('NodeManagerPasswordEncrypted', admin_password)")
    wlst_file.puts("setOption('NodeManagerType', 'PerDomainNodeManager')")
    wlst_file.puts("setOption('OverwriteDomain', 'true')")
    wlst_file.puts()
    wlst_file.puts("cd('/OHS/ohs1')")
    wlst_file.puts("cmo.setAdminHost(admin_host)")
    wlst_file.puts("cmo.setAdminPort(admin_port)")
    wlst_file.puts("cmo.setListenPort(listen_http_port)")
    wlst_file.puts("cmo.setSSLListenPort(listen_https_port)")
    wlst_file.puts()
    wlst_file.puts("cd('/')")
    wlst_file.puts("create('localmachine', 'Machine')")
    wlst_file.puts("cd('Machine/localmachine')")
    wlst_file.puts("create('node-manager', 'NodeManager')")
    wlst_file.puts("cd('NodeManager/node-manager')")
    wlst_file.puts("cmo.setListenAddress('localhost')")
    wlst_file.puts("cmo.setListenPort(node_manager_port)")
    wlst_file.puts("cd('/')")
    wlst_file.puts()
    wlst_file.puts("writeDomain(domain_full_path)")
    wlst_file.puts()
    wlst_file.puts("dumpStack()")
    wlst_file.puts("closeTemplate()")
    wlst_file.puts("exit()")
    wlst_file.puts()

    wlst_file.close
    wlst_file_path = wlst_file.path
    File.chmod(0755, wlst_file_path)
    return wlst_file_path
  end

  def stop_domain

    domain_name = resource[:domain_name]
    Puppet.debug("Stopping domain: #{domain_name}")

    if Facter.value(:osfamily) == 'windows'
      os_user = ''
    else
      os_user = resource[:os_user]
    end
    node_manager_port = resource[:node_manager_port]

    begin
      # check the status of the domain first
      domain_status = OHSUtils.check_domain_status(os_user, domain_name,
                                         node_manager_port, @webserver_hash)
      if domain_status == 'stopped'
        Puppet.debug("Domain #{domain_name} is already stopped")
        return
      end
    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Unable to stop domain #{domain_name}: #{e.message}"
    end
    domain_home_dir = resource[:domain_home_dir]
    OHSUtils.stop_domain(os_user, domain_name, domain_home_dir, @webserver_hash)
  end

  def start_domain(first_boot = false)
    domain_name = resource[:domain_name]

    Puppet.debug("Starting domain: #{domain_name}")

    if Facter.value(:osfamily) == 'windows'
      os_user = ''
    else
      os_user = resource[:os_user]
    end
    node_manager_port = resource[:node_manager_port]

    begin
      # check the status of the domain first
      domain_status = OHSUtils.check_domain_status(os_user, domain_name,
                                         node_manager_port, @webserver_hash)
      if domain_status == 'running'
        Puppet.debug("Domain #{domain_name} is already running")
        return
      end
    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Unable to start domain #{domain_name}: #{e.message}"
    end
    domain_home_dir = resource[:domain_home_dir]
    OHSUtils.start_domain(os_user, domain_name, domain_home_dir, node_manager_port, @webserver_hash, first_boot)
  end

  def restart_domain
    domain_name = resource[:domain_name]
    node_manager_port = resource[:node_manager_port]

    Puppet.debug("Restarting domain #{domain_name}")

    if Facter.value(:osfamily) == 'windows'
      os_user = ''
    else
      os_user = resource[:os_user]
    end
    begin
      command_output = OHSUtils.run_nm_command('nmSoftRestart', os_user, domain_name,
                                     node_manager_port, @webserver_hash)
      domain_status = OHSUtils.check_domain_status(os_user, domain_name,
                                         node_manager_port, @webserver_hash)
      Puppet.debug("Domain #{domain_status} status is #{domain_status}")

    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "OHS domain restart failed: #{e.message}"
    end
  end
end
