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

module Puppet
  Type.newtype(:pt_opa_domain) do
    include EasyType
    include ::PtCompUtils::Validations

    @doc = "Manages the state of PeopleSoft OPA Application Deployment
      domain."

    validate do
      validate_domain_params(self[:os_user], self[:ps_home_dir])

      # make sure os user group is specified, if the os family is not windows
      if Facter.value(:osfamily) != 'Windows' and self[:os_user_group].nil?
        fail("os_user_group attribute should be specified for managing " +
            "a Web Application Deployment domain on Unix platforms")
      end
      if self[:webapp_dir].nil?
        fail("webapp_dir attribute should be specified for managing " +
            "a Web Application Deployment domain")
      end
      if self[:opa_war_file].nil?
        fail("opa_war_file attribute should be specified for managing " +
            "a Web Application Deployment domain")
      end
      #  OPA validations
      ps_app_home = self[:ps_app_home_dir]
      if ps_app_home.nil?
        fail("PS APP Home needs to be specified in the resource")
      end

      opa_dir = File.join(ps_app_home, 'setup', 'archives', 'opa')
      unless FileTest.directory?(opa_dir)
        fail("OPA directory #{opa_dir} does not exists")
      end

      opa_rmod_file = Dir.glob(File.join(opa_dir, '*.rmod'))
      if opa_rmod_file.length == 0
         fail("OPA directory #{opa_dir} is missing the rmod file")
      end

      opa_rules_file = Dir.glob(File.join(opa_dir, '*.zip'))
      if opa_rules_file.length == 0
         fail("OPA directory #{opa_dir} is missing the TL rules file(s)")
      end
      validate_webserver_settings(self[:webserver_type],
                                  self[:webserver_settings])
    end

    ensurable

    newparam(:deployment_type) do

      desc "Specifies the Deployment type for the PeopleSoft Application."

      defaultto :OPA

      newvalues(:OPA)
    end

    newparam(:opa_war_file) do

      desc "Specifies the location of the OPA determinations server war file."

      validate do |value|
        unless Puppet::Util.absolute_path?(value)
          fail Puppet::Error, "OPA determinations server path must be fully " + \
                              "qualified, not '#{value}'"
        end
        unless FileTest.exists?(value)
          fail Puppet::Error, "OPA determinations server war file " + \
                              "#{value} does not exists"
        end
      end
    end

    parameter :domain_name
    parameter :os_user
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
