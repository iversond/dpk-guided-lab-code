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

require 'pathname'
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent)
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent.parent.parent + 'easy_type' + 'lib')

require 'fileutils'
require 'easy_type'
require 'pt_comp_utils/validations'
require 'pt_comp_utils/webserver'

module Puppet
  Type.newtype(:pt_des_domain) do
    include EasyType
    include ::PtCompUtils::Validations
    include ::PtCompUtils::WebServer

    @doc = "Manages the state of PeopleSoft Web Application Deployment
      domain."

    validate do
      validate_domain_params(self[:os_user], self[:ps_home_dir])

      # make sure os user group is specified, if the os family is not windows
      if Facter.value(:osfamily) != 'Windows' and self[:os_user_group].nil?
        fail("os_user group attribute should be specified for managing " +
            "a Web Application Deployment domain on Unix platforms")
      end
      if self[:webapp_dir].nil?
        fail("webapp_dir attribute should be specified for managing " +
            "a Web Application Deployment domain")
      end
      ensure_value = self[:ensure]
      validate_webserver_settings(ensure_value,
                                  self[:webserver_settings])
    end

    ensurable

    newparam(:deployment_type) do

      desc "Specifies the Deployment type for the PeopleSoft Application."

      defaultto :DES

      newvalues(:DES)
    end

    newparam(:db_type) do
      desc "Indicates the database type. Valid values are ORACLE,
        INFORMIX, SYBASE, MICROSFT, DB2ODBC, and DB2UNIX. "

      defaultto :ORACLE

      newvalues(:ORACLE, :INFORMIX, :SYBASE, :MICROSFT, :DB2ODBC, :DB2UNIX)

      validate do |value|
        # validate the database type
        supported_db_list = [ :ORACLE, :INFORMIX, :SYBASE, :MICROSFT,
                              :DB2ODBC, :DB2UNIX ]
        if ! supported_db_list.include?(value)
          fail("Specified db type '#{db_type}' is not one of supported " + \
               "supported databases #{supported_db_list.inspect}")
        end
      end
    end

    newparam(:db_host) do
      desc "Name of the machine hosting the database."
    end

    newparam(:db_port) do
      desc "Denotes the database listening port."

      newvalues(/^\d+$/)

      munge do |value|
        Integer(value)
      end
    end

    newparam(:db_name) do
      desc "Name of the database to connect to."
    end

    newparam(:db_user) do
      desc "Name of the database user."
    end

    newparam(:db_user_pwd) do
      desc "Database user password."

      validate do |value|
        # validate the password
        if value.match(/^(?=.*[\w]).{8,}$/).nil?
          fail("Database password must be at least 8 alphanumeric " + \
               "characters.")
        end
      end
    end

    parameter :domain_name
    parameter :os_user_group
    parameter :ps_home_dir
    parameter :ps_app_home_dir
    parameter :webapp_dir
    parameter :webserver_type
    parameter :webserver_settings
    parameter :http_port
    parameter :https_port

  end
end
