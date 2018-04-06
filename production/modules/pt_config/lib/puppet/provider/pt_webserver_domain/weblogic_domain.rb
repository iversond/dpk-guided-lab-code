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

require 'tempfile'
require 'tmpdir'

require 'pt_comp_utils/validations'
require 'pt_comp_utils/webserver'
require 'puppet/provider/pt_utils'

if Facter.value(:osfamily) == 'windows'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_webserver_domain).provide :weblogic_domain do
  include ::PtCompUtils::Validations
  include ::PtCompUtils::WebServer

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  mk_resource_methods

  def auth_token_domain=(value)
    @property_flush[:auth_token_domain] = value
  end

  def webserver_settings=(value)
    @property_flush[:webserver_settings] = @webserver_hash
  end

  def site_list=(value)
    @property_flush[:site_list] = @site_hash
  end

  def config_settings=(value)
    @property_flush[:config_settings] = value
  end

  def patch_list=(value)
    @property_flush[:patch_list] = value
  end

  def initialize(value={})
    super(value)
    Puppet.debug("Provider Initialization")
    @property_flush = {}
  @webserver_hash = {}
    @site_hash = {}
  end

  def webserver_hash_add(webserver_key, webserver_value)
    if ['pwd', 'pass'].any? {|var| webserver_key.downcase.include? var}
      Puppet.debug("Caching PIA domain Webserver settings: #{webserver_key}:****")
    else
      Puppet.debug("Caching PIA domain Webserver settings: #{webserver_key}:#{webserver_value}")
    end
    @webserver_hash[webserver_key.to_sym] = webserver_value
  end

  def site_hash_add(site_entry)
    Puppet.debug("Caching PIA domain site")
    @site_hash.update(site_entry)
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

    domain_name = resource[:domain_name]
    domain_dir = resource[:ps_cfg_home_dir]

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

    install_dir = File.join(resource[:ps_home_dir], 'setup', 'PsMpPIAInstall')

    first_site = true
    @site_hash.keys.sort.each do |site_name|
      Puppet.debug("Got site name: #{site_name}")
      site_settings = @site_hash[site_name]

      if first_site == true
        response_file = get_new_domain_response_file(site_name, site_settings)

        Puppet.debug("Creating PIA domain: #{domain_name} with the response file")

        begin
          if Facter.value(:osfamily) == 'windows'
            install_cmd = File.join(install_dir, 'setup.bat')

            command = "#{install_cmd} -i silent -DRES_FILE_PATH=\"#{response_file}\""
            execute_command(command, {}, true)

          elsif Facter.value(:osfamily) == 'Solaris'
            install_cmd = File.join(install_dir, 'setup.sh')
            domain_cmd('-', resource[:os_user], '-c',
                       "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
          elsif Facter.value(:osfamily) == 'Linux'
            install_cmd = File.join(install_dir, 'setup.sh')
            domain_cmd('-m', '-l',  resource[:os_user], '-c',
                       "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
          else
            install_cmd = File.join(install_dir, 'setup.sh')
            domain_cmd(resource[:os_user], '-c',
                       "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
          end

          # check if the PIA domain created successfully
          ps_cfg_home = resource[:ps_cfg_home_dir]
          domain_dir = File.join(ps_cfg_home, 'webserv', domain_name)
          if File.exist?(domain_dir) == false
            raise Puppet::ExecutionFailure, "Creation of PIA domain #{domain_name} failed"
          end
          Puppet.debug("Creation of PIA domain #{domain_name} successful")
          FileUtils.remove_file(response_file, :force => true)
          first_site = false

          # install patches if provided
          patch_list = resource[:patch_list]
          if ! patch_list.nil?
            patch_list = [patch_list] unless patch_list.is_a? Array
            patch_list.each do |patch|
              Puppet.debug("Installing patch: #{patch} into #{domain_home}")
              if Facter.value(:osfamily) == 'windows'
                Puppet.debug(" Installing on Windows platform")

                patch = patch.gsub('/', '\\')
                domain_dir = domain_dir.gsub('/', '\\')

                temp_dir_name = Dir.tmpdir()
                extract_file_path = File.join(temp_dir_name, "zip_extract.ps1")
                extract_file = File.open(extract_file_path, 'w')

                extract_file.puts("Try {")
                extract_file.puts("  $shell = new-object -com shell.application")
                extract_file.puts("  $zip = $shell.NameSpace(\"#{patch}\")")
                extract_file.puts("  ForEach($item in $zip.items()) {")
                extract_file.puts("    $shell.Namespace(\"#{domain_dir}\").CopyHere($item, 0x14)")
                extract_file.puts("  }")
                extract_file.puts("  Exit 0")
                extract_file.puts("}")
                extract_file.puts("Catch {")
                extract_file.puts("  $error_message = $_.Exception.Message")
                extract_file.puts("  Write-Host $error_message")
                extract_file.puts("  Exit 1")
                extract_file.puts("}")
                extract_file.close
                File.chmod(0755, extract_file_path)
                Puppet.debug(File.read(extract_file_path))

                system("powershell -File #{extract_zip_script}")
              else
                deploy_user = resource[:os_user]
                Puppet.debug(" Installing on Non Windows platform")
                system("su - #{deploy_user} -c \"unzip -d #{domain_home} #{patch}\"")
              end
              if $? == 0
                Puppet.debug("Installation of PIA domain #{patch} successful")
              else
                Puppet.debug("Installation of PIA domain #{patch} failed")
              end
            end
          else
            Puppet.debug("No PIA domain Patch specified")
          end
        rescue Puppet::ExecutionFailure => e
          raise Puppet::Error, "Failed to create PIA domain #{domain_name}: #{e.message}"
        end
      else
        create_new_pia_site(domain_name, site_name, site_settings)
      end
    end
      post_create()
      @property_hash[:ensure] = :present
  end

  def destroy
    # make sure the ps_home_dir and os_user exits
    ps_home_dir = resource[:ps_home_dir]
    os_user = resource[:os_user]
    validate_params_exists(os_user, ps_home_dir)

    stop_domain()

    delete_domain()

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

    domain_status = get_domain_status()
    if domain_status == 'stopped'
      start_domain
    end
    configure_domain()
    stop_domain()

    if domain_status == 'running'
      start_domain
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

    # make sure the ps_home_dir and os_user exits
    ps_home_dir = resource[:ps_home_dir]
    os_user = resource[:os_user]
    validate_params_exists(os_user, ps_home_dir)

    # make sure the  Gateway password is given
    if resource[:gateway_user_pwd].nil?
      raise ArgumentError, "Integration Gateway user password needs to " +
                           "specified to create a WebServer domain"
    end
  end

  def post_create
    domain_name = resource[:domain_name]

    Puppet.debug("Post Create domain: #{domain_name}")

    start_needed = false
    if ! resource[:config_settings].nil?
      @property_flush[:config_settings] = resource[:config_settings]
      start_needed = true
    end
    if start_needed
      start_domain()
    end
    configure_domain()
    if start_needed
      stop_domain()
    end

    domain_start = resource[:domain_start]
    if domain_start.to_s == "true"
      Puppet.debug("Domain start requested")
      start_domain()
    end
  end

  def configure_domain
    domain_name = resource[:domain_name]

    Puppet.debug("Configuring domain: #{domain_name}")
    if @property_flush.size == 0
      Puppet.debug("Nothing to configure")
      return
    end
    # configure the WebServer settings if specified
    config_settings = @property_flush[:config_settings]
    if config_settings.nil? == false
      Puppet.debug('Updating PIA domain #{domain_name} config settings')

      wlst_file = Tempfile.new(['pia-config', '.py'])

      wlst_file.puts("import os")
      wlst_file.puts()
      wlst_file.puts("admin_user = '#{@webserver_hash[:webserver_admin_user]}'")
      wlst_file.puts("admin_password = '#{@webserver_hash[:webserver_admin_user_pwd]}'")
      wlst_file.puts("admin_port = '#{@webserver_hash[:webserver_admin_port]}'")
      wlst_file.puts("admin_url = 't3://localhost:' + admin_port")
      wlst_file.puts()
      wlst_file.puts("connect(admin_user, admin_password, admin_url)")
      wlst_file.puts()
      wlst_file.puts("edit()")
      wlst_file.puts("startEdit()")
      wlst_file.puts()

      config_settings.each do |config|
        context_path = config.split('=', 2)[0].strip
        context_settings = config.split('=', 2)[1].strip

        wlst_file.puts("cd('/')")
        wlst_file.puts("cd('#{context_path}')")

        context_settings.delete!("\n[]\"")
        Puppet.debug("Updating setting 1 #{context_settings.inspect} class #{context_settings.class}")

        context_settings_array = context_settings.split(", ")
        Puppet.debug("Updating setting 2 #{context_settings_array.inspect} class #{context_settings_array.class}")
        for index in (0...context_settings_array.length)
          context_setting = context_settings_array[index]
          setting_name = context_setting.split('=', 2)[0].strip
          setting_value = context_setting.split('=', 2)[1].strip
          Puppet.debug("Found setting: #{setting_name}=#{setting_value}")
          wlst_file.puts("set('#{setting_name}', '#{setting_value}')")
        end
        wlst_file.puts()
      end
      wlst_file.puts("activate(200000, block='true')")
      wlst_file.puts("exit()")
      wlst_file.close
      wlst_file_path = wlst_file.path
      File.chmod(0755, wlst_file_path)
      Puppet.debug(" with response: #{File.read(wlst_file_path)}")

      # setup weblogic environment
      wl_home = File.join(@webserver_hash[:webserver_home], 'wlserver')
      ENV['WL_HOME'] = wl_home
      wl_jar_file = File.join(wl_home, 'server', 'lib', 'weblogic.jar')

      if Facter.value(:osfamily) == 'windows'
        cmd_prefix = ''
        cmd_suffix = ''
        classpath = "%CLASSPATH%"
        path_separator = ';'
        ENV['CLASSPATH'] = wl_jar_file
      else
        cmd_prefix = "su - #{resource[:os_user]} -p -c \""
        cmd_suffix = "\""
        classpath = "$CLASSPATH"
        path_separator = ':'
        ENV['CLASSPATH'] = ".#{path_separator}#{wl_jar_file}"
      end

      log_file = Tempfile.new(['wlst-log', 'log'])
      log_file_path = log_file.path
      File.chmod(0755, log_file_path)

      java_opts = "-Dwlst.offline.log=#{log_file_path} -cp #{classpath}"
      wl_config_cmd = "#{cmd_prefix} java #{java_opts} weblogic.WLST " + \
                       "-skipWLSModuleScanning #{wlst_file_path} #{cmd_suffix}"
      Puppet.debug("WLST config command: #{wl_config_cmd}")

      begin

      if Facter.value(:osfamily) == 'windows'
         command_output = execute_command(wl_config_cmd)
      else
        command_output = Puppet::Util::Execution.execute(wl_config_cmd, :failonfail => true)
        end
        Puppet.debug("PIA domain #{domain_name} configured successfully")

      rescue Puppet::ExecutionFailure => e
        Puppet.debug("PIA domain update config error: #{e.message}, output: #{command_output}")
        raise e
      end
    end
    webserver_settings = @property_flush[:webserver_settings]
    if webserver_settings.nil? == false
      Puppet.debug("Updating PIA domain #{domain_name} WebServer settings")
    end

    new_auth_token_domain = @property_flush[:auth_token_domain]
    if new_auth_token_domain.nil? == false
      Puppet.debug("Updating PIA domain #{domain_name} auth token domain")
    end

    site_list_hash = @property_flush[:site_list]
    if site_list_hash.nil? == false
      configure_pia_sites(site_list_hash)
    end
    @property_flush.clear
  end

  # This function generates the response file (user inputs) to create a new
  # PIA domain. This response file is used by the PIA installer to run in a
  #  silent mode
  def get_new_domain_response_file(site_name, site_settings)
    domain_name = resource[:domain_name]
    domain_dir  = resource[:ps_cfg_home_dir]

    temp_dir_name = Dir.tmpdir()
    response_file_path = File.join(temp_dir_name, "wl-create-domain.rsp")
    response_file = File.open(response_file_path, 'w')

    response_file.puts("PS_HOME=#{domain_dir}")
    response_file.puts("DOMAIN_NAME=#{domain_name}")
    response_file.puts('DOMAIN_TYPE=NEW_DOMAIN')
    response_file.puts('INSTALL_ACTION=CREATE_NEW_DOMAIN')
    response_file.puts('INSTALL_TYPE=SINGLE_SERVER_INSTALLATION')

    response_file.puts("SERVER_TYPE=#{@webserver_hash[:webserver_type]}")
    response_file.puts("BEA_HOME=#{@webserver_hash[:webserver_home]}")
    response_file.puts("USER_ID=#{@webserver_hash[:webserver_admin_user]}")
    webserver_admin_pwd = @webserver_hash[:webserver_admin_user_pwd]
    response_file.puts("USER_PWD=#{webserver_admin_pwd}")
    response_file.puts("USER_PWD_RETYPE=#{webserver_admin_pwd}")

    authtoken_domain = resource[:auth_token_domain].strip
        
    if authtoken_domain.nil? || authtoken_domain == "."
      authtoken_domain = ''
    end

    # auth_token_domain should be blank for VBOX Guest Linux VM
    # Check if it is VBOX VM and making it blank.
    
    if (Facter.value(:is_virtual) == true)  
        if (Facter.value(:virtual) == 'virtualbox')
          authtoken_domain = ''       
        end           
    end   
    
    response_file.puts("AUTH_DOMAIN=#{authtoken_domain}")

    response_file.puts("WEBSITE_NAME=#{site_name}")
    response_file.puts("HTTP_PORT=#{@webserver_hash[:webserver_http_port].to_s}")
    response_file.puts("HTTPS_PORT=#{@webserver_hash[:webserver_https_port].to_s}")

    response_file.puts("PSSERVER=#{site_settings[:appserver_connections]}")

    webprofile_hash = site_settings[:webprofile_settings]
    response_file.puts("WEB_PROF_NAME=#{webprofile_hash[:profile_name]}")
    response_file.puts("WEB_PROF_USERID=#{webprofile_hash[:profile_user]}")
    profile_user_pwd = webprofile_hash[:profile_user_pwd]
    response_file.puts("WEB_PROF_PWD=#{profile_user_pwd}")
    response_file.puts("WEB_PROF_PWD_RETYPE=#{profile_user_pwd}")

    response_file.puts("IGW_USERID=#{resource[:gateway_user]}")
    gateway_user_pwd = resource[:gateway_user_pwd]
    response_file.puts("IGW_PWD=#{gateway_user_pwd}")
    response_file.puts("IGW_PWD_RETYPE=#{gateway_user_pwd}")

    domain_conn_pwd = site_settings[:domain_conn_pwd]
    if domain_conn_pwd.nil?
      domain_conn_pwd = ''
    end
    response_file.puts("APPSRVR_CONN_PWD=#{domain_conn_pwd}")
    response_file.puts("APPSRVR_CONN_PWD_RETYPE=#{domain_conn_pwd}")

    response_file.puts("REPORTS_DIR=#{site_settings[:report_repository_dir]}")

    response_file.close
    File.chmod(0755, response_file_path)
    return response_file_path
  end

  #
  # This function generates the response file (user inputs) to create a new
  # PIA domain site. This response file is used by the PIA installer to run in a
  #  silent mode
  def get_new_site_response_file(site_name, site_settings)
    domain_name = resource[:domain_name]
    domain_dir  = resource[:ps_cfg_home_dir]

    temp_dir_name = Dir.tmpdir()
    response_file_path = File.join(temp_dir_name, "wl-create-site.rsp")
    response_file = File.open(response_file_path, 'w')

    response_file.puts("PS_HOME=#{domain_dir}")
    response_file.puts("DOMAIN_NAME=#{domain_name}")
    response_file.puts('DOMAIN_TYPE=EXISTING_DOMAIN')
    response_file.puts('INSTALL_ACTION=ADD_SITE')
    response_file.puts('INSTALL_TYPE=SINGLE_SERVER_INSTALLATION')

    response_file.puts("SERVER_TYPE=#{@webserver_hash[:webserver_type]}")
    response_file.puts("BEA_HOME=#{@webserver_hash[:webserver_home]}")
    response_file.puts("USER_ID=#{@webserver_hash[:webserver_admin_user]}")
    webserver_admin_pwd = @webserver_hash[:webserver_admin_user_pwd]
    response_file.puts("USER_PWD=#{webserver_admin_pwd}")
    response_file.puts("USER_PWD_RETYPE=#{webserver_admin_pwd}")

    authtoken_domain = resource[:auth_token_domain].strip
   
    if authtoken_domain.nil? || authtoken_domain == "."
      authtoken_domain = ''
    end
    
    # auth_token_domain should be blank for VBOX Guest Linux VM
    # Check if it is VBOX VM and making it blank.
    
    if (Facter.value(:is_virtual) == true)  
        if (Facter.value(:virtual) == 'virtualbox')
          authtoken_domain = ''       
        end           
    end   
       
    response_file.puts("AUTH_DOMAIN=#{authtoken_domain}")

    response_file.puts("WEBSITE_NAME=#{site_name}")
    response_file.puts("HTTP_PORT=#{@webserver_hash[:webserver_http_port].to_s}")
    response_file.puts("HTTPS_PORT=#{@webserver_hash[:webserver_https_port].to_s}")

    response_file.puts("PSSERVER=#{site_settings[:appserver_connections]}")

    webprofile_hash = site_settings[:webprofile_settings]
    response_file.puts("WEB_PROF_NAME=#{webprofile_hash[:profile_name]}")
    response_file.puts("WEB_PROF_USERID=#{webprofile_hash[:profile_user]}")
    profile_user_pwd = webprofile_hash[:profile_user_pwd]
    response_file.puts("WEB_PROF_PWD=#{profile_user_pwd}")
    response_file.puts("WEB_PROF_PWD_RETYPE=#{profile_user_pwd}")

    response_file.puts("IGW_USERID=#{resource[:gateway_user]}")
    gateway_user_pwd = resource[:gateway_user_pwd]
    response_file.puts("IGW_PWD=#{gateway_user_pwd}")
    response_file.puts("IGW_PWD_RETYPE=#{gateway_user_pwd}")

    domain_conn_pwd = site_settings[:domain_conn_pwd]
    if domain_conn_pwd.nil?
      domain_conn_pwd = ''
    end
    response_file.puts("APPSRVR_CONN_PWD=#{domain_conn_pwd}")
    response_file.puts("APPSRVR_CONN_PWD_RETYPE=#{domain_conn_pwd}")

    response_file.puts("REPORTS_DIR=#{site_settings[:report_repository_dir]}")

    response_file.close
    File.chmod(0755, response_file_path)
    return response_file_path
  end

  def get_domain_status
    domain_name = resource[:domain_name]
    ps_cfg_home = resource[:ps_cfg_home_dir]

    Puppet.debug("Getting domain #{domain_name} status")

    domain_dir = File.join(ps_cfg_home, 'webserv', domain_name, 'bin')

    domain_status = 'running'
    begin
      if Facter.value(:osfamily) == 'windows'
        status_cmd = File.join(domain_dir, 'singleserverStatus.cmd')
        status_msg = execute_command(status_cmd)
      else
        status_cmd = File.join(domain_dir, 'singleserverStatus.sh')
        if Facter.value(:osfamily) == 'Linux'
          status_msg = domain_cmd('-m', '-l',  resource[:os_user], '-c', "#{status_cmd}")
        else
          status_msg = domain_cmd(resource[:os_user], '-c', "#{status_cmd}")
        end
      end
      if status_msg.include?('Failed')
        Puppet.debug("Domain #{domain_name} stopped")
        domain_status = 'stopped'
      end
    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Unable to get the status of domain #{domain_name}: #{e.message}"
    end
    return domain_status
  end

  def stop_domain
    domain_name = resource[:domain_name]
    ps_cfg_home = resource[:ps_cfg_home_dir]

    Puppet.debug("Stopping domain: #{domain_name}")

    domain_dir = File.join(ps_cfg_home, 'webserv', domain_name, 'bin')

    # check the status of the domain first
    domain_status = get_domain_status()
    if domain_status == 'running'
      # stop the domain
      begin
        if Facter.value(:osfamily) == 'windows'
          stop_cmd = File.join(domain_dir, 'stopPIA.cmd')
          execute_command(stop_cmd)
        else
          stop_cmd = File.join(domain_dir, 'stopPIA.sh')
          if Facter.value(:osfamily) == 'Linux'
            domain_cmd('-m', '-l',  resource[:os_user], '-c', "#{stop_cmd}")
          else
            domain_cmd(resource[:os_user], '-c', "#{stop_cmd}")
          end
        end

      rescue Puppet::ExecutionFailure => e
        raise Puppet::Error, "Unable to stop the domain #{domain_name}: #{e.message}"
      end
    end
  end

  def delete_domain
    domain_name = resource[:domain_name]

    # remove the domain directory
    domain_dir = File.join(resource[:ps_cfg_home_dir], 'webserv', domain_name)
    FileUtils.rm_rf(domain_dir)

    if Facter.value(:osfamily) == 'windows'
      # remove PIA windows service
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

    Puppet.debug("Starting domain: #{domain_name}")

    domain_dir = File.join(ps_cfg_home, 'webserv', domain_name, 'bin')
    begin
      if Facter.value(:osfamily) == 'windows'
        os_user = nil
        start_cmd = File.join(domain_dir, 'startPIA.cmd')
        domain_pid = Process.spawn "#{start_cmd}"
        Puppet.debug("Spawned process #{domain_pid} to start PIA")
      else
        os_user = resource[:os_user]
        start_cmd = File.join(domain_dir, 'startPIA.sh')
        if Facter.value(:osfamily) == 'Linux'
          domain_cmd('-m', '-l',  os_user, '-c', "#{start_cmd}")
        else
          domain_cmd(os_user, '-c', "#{start_cmd}")
        end
      end

      bea_home = "#{@webserver_hash[:webserver_home]}"
      admin_user = "#{@webserver_hash[:webserver_admin_user]}"
      admin_pwd = "#{@webserver_hash[:webserver_admin_user_pwd]}"
      http_port = "#{@webserver_hash[:webserver_http_port].to_s}"

      if is_weblogic_server_running?(os_user, bea_home, http_port,
                                     admin_user, admin_pwd, "PIA") == false
        raise Puppet::Error, "Unable to get the status of domain #{domain_name}"
      end

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Unable to start domain #{domain_name}: #{e.message}"
    end
  end

  def configure_pia_sites(site_list_hash)
      domain_name = resource[:domain_name]
      ps_cfg_home = resource[:ps_cfg_home_dir]

      Puppet.debug("Updating PIA domain #{domain_name} site information")

      # get the new PIA site list
      new_pia_site_list = site_list_hash.keys

      # get the current site list
      cur_pia_site_list = get_current_pia_site_list()

      # remove the PIA sites if not present in the Hash
      cur_pia_site_list.each do |cur_pia_site|
        Puppet.debug("Checking if current site #{cur_pia_site} should be removed")

        if new_pia_site_list.include?(cur_pia_site) == false
          Puppet.debug("Site #{cur_pia_site} does not exists in the Hash, remove the site")

          FileUtils.rm_rf(File.join(ps_cfg_home, 'webserv', domain_name, 'applications',
                                    'peoplesoft', 'PORTAL.war', 'WEB-INF', 'psftdocs', cur_pia_site))
          FileUtils.rm_rf(File.join(ps_cfg_home, 'webserv', domain_name, 'applications',
                                    'peoplesoft', 'PORTAL.war', cur_pia_site))
        end
      end
      new_pia_site_list.each do |new_pia_site|
        site_settings = site_list_hash[new_pia_site]

        Puppet.debug("Checking if new site #{new_pia_site} already exists")

        if cur_pia_site_list.include?(new_pia_site)
          appserver_connections = site_settings[:appserver_connections]

          config_prop_file = File.join(ps_cfg_home, 'webserv', domain_name, 'applications',
                                 'peoplesoft', 'PORTAL.war', 'WEB-INF', 'psftdocs',
                                 new_pia_site, 'configuration.properties')
          Puppet.debug("Updating PIA site #{new_pia_site} configuration properties file #{config_prop_file}")

          pia_config_text = File.read(config_prop_file)
          content = pia_config_text.gsub(/^psserver=.*$/, "psserver=#{appserver_connections}")
          File.open(config_prop_file, "w") { |file| file << content }
        else
          stop_domain

          create_new_pia_site(domain_name, new_pia_site, site_settings)
        end
      end
  end

  def get_current_pia_site_list()
    domain_name = resource[:domain_name]
    ps_cfg_home = resource[:ps_cfg_home_dir]


    pia_site_dir = File.join(ps_cfg_home, 'webserv', domain_name, 'applications',
                             'peoplesoft', 'PORTAL.war', 'WEB-INF', 'psftdocs')
    Puppet.debug("Getting the current site list for domain #{domain_name} from directory #{pia_site_dir}")
    pia_site_list = Dir.entries(pia_site_dir).select {|entry| File.directory?(File.join(pia_site_dir, entry)) and !(entry =='.' || entry == '..') }

    Puppet.debug("Current PIA domain site list: #{pia_site_list.inspect}")
    return pia_site_list
  end

  def create_new_pia_site(domain_name, site_name, site_settings)
    install_dir = File.join(resource[:ps_home_dir], 'setup', 'PsMpPIAInstall')

    response_file = get_new_site_response_file(site_name, site_settings)

    Puppet.debug("Creating a new site for PIA domain: #{domain_name}")
    Puppet.debug(" with response:\n #{File.read(response_file)}")

    begin
      if Facter.value(:osfamily) == 'windows'
        install_cmd = File.join(install_dir, 'setup.bat')

        command = "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}"
        execute_command(command)
      else
        install_cmd = File.join(install_dir, 'setup.sh')
        if Facter.value(:osfamily) == 'Linux'
          domain_cmd('-m', '-l',  resource[:os_user], '-c',
                   "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
        else
          domain_cmd(resource[:os_user], '-c',
                   "#{install_cmd} -i silent -DRES_FILE_PATH=#{response_file}")
        end
      end
      FileUtils.remove_file(response_file, :force => true)
      Puppet.debug("Creation of PIA domain #{domain_name} site #{site_name} successful")

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Failed to create site #{site_name} for PIA domain #{domain_name}: #{e.message}"
    end
  end
end
