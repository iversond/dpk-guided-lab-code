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

require 'puppet/provider/psftdomain'

if Facter.value(:osfamily) == 'windows'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_appserver_domain).provide :appserver_domain,
                  :parent => Puppet::Provider::PsftDomain do

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  mk_resource_methods

  def feature_settings=(value)
     @property_flush[:feature_settings] = value
  end

  def config_settings=(value)
    @property_flush[:config_settings] = value
  end

  def env_settings=(value)
  end

  private

  def get_startup_settings
    empty_param = "_____"

    if Facter.value(:osfamily) == 'windows'
      param_separator = '/'

      dbdir = resource[:db_home_dir]
      if dbdir.nil?
        add_to_path = empty_param
      else
        add_to_path = File.join(dbdir, 'bin')
        add_to_path = add_to_path.gsub('/', '\\')
        add_to_path = "\"#{add_to_path}\""
      end
    else
      param_separator = '%'
      add_to_path = "."
    end

    domain_name = resource[:domain_name]
    if @db_hash.size != 0

      db_server_name = @db_hash[:db_server_name]
      if db_server_name.nil?
        db_server_name = empty_param
      end

      if @db_hash[:db_type] == 'MSSQL'
        db_type = 'MICROSFT'
      else
        db_type = @db_hash[:db_type]
      end
      startup_settings = @db_hash[:db_name] + param_separator + \
                         db_type + param_separator + \
                         @db_hash[:db_opr_id] + param_separator + \
                         @db_hash[:db_opr_pwd] + param_separator + \
                         domain_name + param_separator + \
                         add_to_path + param_separator + \
                         @db_hash[:db_connect_id] + param_separator + \
                         @db_hash[:db_connect_pwd] + param_separator + \
                         db_server_name + param_separator + \
                         empty_param
    else
      startup_settings = doman_name
    end
    Puppet.debug("Startup settings: #{startup_settings.gsub(@db_hash[:db_opr_pwd], '****').gsub(@db_hash[:db_connect_pwd], '****')}")
    return "#{get_startup_option} #{startup_settings}"
  end

  def get_startup_option
    return "-s"
  end

  def get_template_type
    return "-t #{resource[:template_type].to_s}"
  end

  def get_domain_type
    return "-c"
  end

  def pre_create
    super()

    domain_name = resource[:domain_name]
    cfg_home_dir = resource[:ps_cfg_home_dir]

    domain_dir = File.join(cfg_home_dir, 'appserv', domain_name)
    if File.exist?(domain_dir)
      Puppet.debug("Removing Application Server domain directory: #{domain_dir}")
      FileUtils.rm_rf(domain_dir)
    end
  end

  def post_delete
    domain_name = resource[:domain_name]
    cfg_home_dir = resource[:ps_cfg_home_dir]
    Puppet.debug("Removing Application Server domain directory")
    FileUtils.rm_rf(File.join(cfg_home_dir, 'appserv', domain_name))

    if Facter.value(:osfamily) == 'windows'
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
end
