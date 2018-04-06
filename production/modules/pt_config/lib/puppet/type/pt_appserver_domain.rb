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
require 'puppet/parameter/boolean'

module Puppet
  Type.newtype(:pt_appserver_domain) do
    include EasyType
    include ::PtCompUtils::Validations

    @doc = "Manages the state of PeopleTools Application Server domain."

    validate do
      validate_domain_params(self[:os_user], self[:ps_home_dir])
      validate_keyvalue_array(self[:feature_settings])

      if self[:ensure] == 'present' && self[:db_home_dir].nil?
        fail("db_home_dir attribute should be specified")
      end
    end

    ensurable

    newparam(:template_type) do
      desc "Specify the name of the template that is used as a basis for the
        domain configuration for Application Server domain."

      defaultto :small

      newvalues(:developer, :small, :medium, :large)
    end

    newproperty(:feature_settings, :array_matching => :all) do
      desc "Specifies a list of feature settings to be applied to  the
        Application Server domain."

      validate do |value|
        raise ArgumentError,
          "Key/value pairs must be separated by an =" unless value.include?("=")
      end
    end

    newproperty(:config_settings, :array_matching => :all) do
      desc "Specifies the list of configuration settings to be applied
        to the Application Server domain."

      validate do |value|
        raise ArgumentError,
          "Key/value pairs must be separated by an =" unless value.include?("=")
      end
    end

    newproperty(:env_settings, :array_matching => :all) do
      desc "Specifies the list of environment settings to be applied
        to the Application Server domain."

      validate do |value|
        raise ArgumentError,
          "Key/value pairs must be separated by an =" unless value.include?("=")
      end
    end

    parameter :domain_name
    parameter :os_user
    parameter :ps_home_dir
    parameter :ps_cfg_home_dir
    parameter :ps_app_home_dir
    parameter :ps_cust_home_dir
    parameter :db_settings
    parameter :db_home_dir
    parameter :domain_start
    parameter :recreate
  end
end
