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

require 'fileutils'
require 'etc'
require 'puppet/provider/webappdomain'

Puppet::Type.type(:pt_des_domain).provide :des_domain,
                  :parent => Puppet::Provider::WebAppDomain do

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  mk_resource_methods

  private

  def configure_domain
    if Facter.value(:osfamily) == 'windows'
      script_suffix = '.bat'
      class_path_separator = ';'
    else
      script_suffix = '.sh'
      class_path_separator = ':'
    end
    # setup xalan.jar & xerces in setEnv.sh file in DES domain
    set_env_file = File.join(resource[:webap_dir], 'webserv',
                                      resource[:domain_name], 'bin',
                                      'setEnv' + script_suffix)
    Puppet.debug("Updating DES domain env file #{set_env_file}")

    file_content_orig = File.read(set_env_file)
    file_content_mod = file_content_orig.gsub(/psjoa.jar/, 'psjoa.jar' + \
                       class_path_separator + \
                       '\${PS_HOME}\/webserv\/\${DOMAIN_NAME}\/lib\/xalan.jar' + \
                       class_path_separator + \
                       '\${PS_HOME}\/webserv\/\${DOMAIN_NAME}\/lib\/xercesImpl.jar')
    File.open(set_env_file, "w") { |file| file << file_content_mod }

    ojdbc_jar = 'ojdbc6.jar'
    wl_jdbc_file = File.join(resource[:webserver_settings]['webserver_dir'],
                            'oracle_common', 'modules',
                            'oracle.jdbc_12.1.0', ojdbc_jar)
    des_app_dir = File.join(resource[:webapp_dir], 'webserv',
                            resource[:domain_name], 'applications', 'crm')
    Puppet.debug("Copying JDBC Driver from #{wl_jdbc_file} " + \
                 "to #{des_app_dir}")
    FileUtils.cp(wl_jdbc_file, des_app_dir)

    if Facter.value(:osfamily) == 'windows'
      appsrv_classes_dir = File.join(resource[:ps_app_home_dir], 'class')
    else
      appsrv_classes_dir = File.join(resource[:ps_app_home_dir], 'appserv',
                                    'classes')
    end
    Puppet.debug("Copying JDBC Driver from #{wl_jdbc_file} " + \
                 "into #{appserv_classes_dir}")
    FileUtils.cp(wl_jdbc_file, appsrv_classes_dir)

    # change the ownership of of the JDBC driver
    if Facter.value(:osfamily) != 'windows'
      user = resource[:os_user]
      group = resource[:os_user_group]

      uid = Etc.getpwnam(user).uid
      gid = Etc.getgrnam(group).gid
      Puppet.debug("User #{user}:uid #{uid}, Group #{group}:gid #{gid}")

      File.chown(uid, gid, File.join(des_app_dir, ojdbc_jar))
      File.chown(uid, gid, File.join(appsrv_classes_dir, ojdbc_jar))
    end

    super()
  end

  def get_response_file
    response_file_path = super()

    # add DES relarted properties to the response file
    open(response_file_path,  'a') do |response_file|
      response_file.puts('DB_TYPE=' + resource[:db_type].to_s)
      response_file.puts('DB_SERVER_NAME=' + resource[:db_host])
      response_file.puts('DB_PORT=' + resource[:db_port])
      response_file.puts('DB_SERVER_INSTANCE=' + resource[:db_name])
      response_file.puts('DB_USER=' + resource[:db_user])
      response_file.puts('DB_PASSWORD=' + resource[:db_user_pwd])
    end
    return response_file_path
  end
end
