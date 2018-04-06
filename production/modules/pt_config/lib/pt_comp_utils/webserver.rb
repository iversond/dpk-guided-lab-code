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

require 'tmpdir'
require 'tempfile'
require 'open3'

module PtCompUtils
  module WebServer

    def self.included(parent)
      parent.extend(WebServer)
    end

    def check_webserver_domain_exists?(domain_dir, domain_name)

      Puppet.debug("Checking if WebServer domain #{domain_name} " +
                   "already installed")
      domain_exists = true

      domain_path = File.join(domain_dir, 'webserv', domain_name)
      config_file = File.join(domain_path, 'config', 'config.xml')
      Puppet.debug("Checking if config file #{config_file} exists")
      if FileTest.exists?(config_file) == false
        domain_exists = false
      end
      return domain_exists
    end

    def validate_webserver_settings_array(ensure_value, webserver_settings)
      webserver_settings_hash = {}
      webserver_settings.each do |webserver_setting|
        webserver_setting = webserver_setting.join(",")

        webserver_setting_key = webserver_setting.split('=', 2)[0].strip
        webserver_setting_val = webserver_setting.split('=', 2)[1].strip

        webserver_settings_hash[webserver_setting_key.to_sym] = webserver_setting_val
      end
      validate_webserver_settings(ensure_value, webserver_settings_hash)
    end

    def validate_webserver_settings(ensure_value, webserver_settings)
      if ensure_value == 'present'
        # make sure WebServer settings are given
        if webserver_settings.nil?
          raise ArgumentError, "webserver_settings needs to be specified " +
                               "to create a Webserver domain"
        end
        webserver_hash = Hash.new do |h,k|
          fail("#{k} needs to be specified in the webserver_settings " +
               "parameter")
        end
        webserver_hash.update(webserver_settings)
        # validate to make sure all the required WebServer parameters are
        # specified
        key_webserver_home       = :webserver_home
        key_webserver_admin_user = :webserver_admin_user
        key_webserver_admin_pwd  = :webserver_admin_user_pwd
        key_webserver_type       = :webserver_type
        key_webserver_admin_port = :webserver_admin_port
        key_webserver_http_port  = :webserver_http_port
        key_webserver_https_port = :webserver_https_port

        webserver_type = webserver_hash[key_webserver_type]
        if (webserver_type != 'weblogic') and (webserver_type != 'websphere') and (webserver_type != 'ohs')
          fail("WebServer type should be either 'weblogic' or 'websphere' or 'ohs', got: [#{item_val}]")
        end
        if webserver_type == 'websphere'
          fail("WebSphere is not supported as the WebServer in this release")
        end
        webserver_home = webserver_hash[key_webserver_home]
        unless Puppet::Util.absolute_path?(webserver_home)
          fail("Webserver Home must be fully qualified, not '#{webserver_home}'")
        end
        if webserver_hash[key_webserver_type]  == 'weblogic'
          webserver_hash[key_webserver_admin_user]
          admin_pwd = webserver_hash[key_webserver_admin_pwd]
          if admin_pwd.match(/^(?=.*[a-z])(?=.*[A-Z])(?=.*[\d|\W]).{8,}$/).nil?
            warning("Webserver admin password is advised to be at least 8 characters with " +
                 "atleast one uppercase, one lowercase and one number or a " +
                 "special character.")
          end
          http_port = webserver_hash[:webserver_http_port]
          Puppet.debug("Webserver HTTP Port: #{http_port}")
          if http_port.match(/^\d+$/).nil?
            fail('HTTP Port should only contain numeric values')
          end
          https_port = webserver_hash[:webserver_https_port]
          Puppet.debug("Webserver HTTPS Port: #{https_port}")
          if https_port.match(/^\d+$/).nil?
            fail('HTTPS Port should only contain numeric values')
          end
        end
      end
    end

    def validate_ohs_webserver_settings(webserver_settings)
      # make sure WebServer settings are given
      if webserver_settings.nil?
        raise ArgumentError, "webserver_settings needs to be specified " +
                             "to manage a OHS Webserver domain"
      end
      webserver_hash = Hash.new do |h,k|
        fail("#{k} needs to be specified in the webserver_settings " +
             "parameter")
      end
      webserver_hash.update(webserver_settings)
      # validate to make sure all the required WebServer parameters are
      # specified
      key_webserver_home       = :webserver_home
      key_webserver_admin_user = :webserver_admin_user
      key_webserver_admin_pwd  = :webserver_admin_user_pwd
      key_webserver_type       = :webserver_type
      key_webserver_admin_port = :webserver_admin_port
      key_webserver_http_port  = :webserver_http_port
      key_webserver_https_port = :webserver_https_port

      webserver_home = webserver_hash[key_webserver_home]
      unless Puppet::Util.absolute_path?(webserver_home)
        fail("Webserver Home must be fully qualified, not '#{webserver_home}'")
      end
      if webserver_hash[key_webserver_type]  == 'weblogic'
        webserver_hash[key_webserver_admin_user]
        admin_pwd = webserver_hash[key_webserver_admin_pwd]
        if admin_pwd.match(/^(?=.*[a-z])(?=.*[A-Z])(?=.*[\d|\W]).{8,}$/).nil?
          warning("Webserver admin password is advised to be at least 8 characters with " +
               "atleast one uppercase, one lowercase and one number or a " +
               "special character.")
        end
        http_port = webserver_hash[:webserver_http_port]
        if http_port.match(/^\d+$/).nil?
          fail('HTTP Port should only contain numeric values')
        end
        https_port = webserver_hash[:webserver_https_port]
        if https_port.match(/^\d+$/).nil?
          fail('HTTPS Port should only contain numeric values')
        end
      end
    end

    # This method checks WebLogic Server status and returns 'true' if the server
    # is up and running. If the Server fails to comeup after sometime, a status
    # of 'false' is returned
    def is_weblogic_server_running?(os_user, bea_home, domain_port,
                                    admin_user, admin_pwd, server_name)

      if Facter.value(:osfamily) == 'windows'
        host_name=Facter.value(:fqdn)
      else
        host_name = 'localhost'
      end

      log_file = Tempfile.new(['wlst-log', '.log'])
      wlst_log_file = log_file.path
      File.chmod(0755, wlst_log_file)

      # generate the jython script to check the WebLogic server status
      wl_script_file = File.join(Dir.tmpdir(), 'wl-status.py')
      File.open(wl_script_file, 'w') do |script_file|
        script_file.puts(
          "connect('#{admin_user}', '#{admin_pwd}', 't3://#{host_name}:#{domain_port}')")
        script_file.puts("domainRuntime()")
        script_file.puts("try:")
        script_file.puts("  srvBean=cmo.lookupServerLifeCycleRuntime('#{server_name}')")
        script_file.puts("  srvState=srvBean.getState()")
        script_file.puts("except:")
        script_file.puts("  srvState='UNKNOWN'")
        script_file.puts("print srvState")
      end
      File.chmod(0755, wl_script_file)

      if Facter.value(:osfamily) == 'windows'
        cmd_prefix = ''
        cmd_suffix = ''
        classpath = "%CLASSPATH%"
        path_separator = ';'
      elsif Facter.value(:osfamily) == 'AIX'
        cmd_prefix = "su - #{os_user} -c \""
        cmd_suffix = "\""
        classpath = "$CLASSPATH"
        path_separator = ':'
      else
        cmd_prefix = "su - #{os_user} -p -c \""
        cmd_suffix = "\""
        classpath = "$CLASSPATH"
        path_separator = ':'
      end

      # setup weblogic environment
      wl_home = File.join(bea_home, 'wlserver')
      ENV['WL_HOME'] = wl_home
      wl_jar_file = File.join(wl_home, 'server', 'lib', 'weblogic.jar')
      ENV['CLASSPATH'] = ".#{path_separator}#{wl_jar_file}"

      java_opts = "-Dwlst.offline.log=#{wlst_log_file} -cp #{classpath}"
      wl_status_cmd = "#{cmd_prefix} java #{java_opts} weblogic.WLST " + \
                    "-skipWLSModuleScanning #{wl_script_file} #{cmd_suffix}"

      Puppet.debug("WLST status command: #{wl_status_cmd}")

      count = 1
      status = 'UNKNOWN'
      while status != 'RUNNING'
        begin
          Open3.popen3(wl_status_cmd) do |stdin, out, err|
            stdin.close
            out_str = out.read

            status = out_str.split.last
          end
        rescue
          error_str = err.read
          File.delete(wl_script_file)
          fail("Error while checking Weblogic server #{server_name} status" +
               "Error: #{error_str}")
        end
        count += 1
        if count >= 100
          break
        end
      end
      File.delete(wl_script_file)

      if status == 'RUNNING'
        Puppet.debug("WebLogic Server #{server_name} is running")
        return true
      else
        Puppet.debug("There is some problem accessing the status of " +
                     "Weblogic server #{server_name}")
        return false
      end
    end
  end
end
