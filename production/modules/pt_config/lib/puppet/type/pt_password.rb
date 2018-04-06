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
require 'puppet/parameter/boolean'

module Puppet
  Type.newtype(:pt_password) do
    include EasyType
    include ::PtCompUtils::Validations

    @doc = 'Changes the passwords with respect to PeopleSoft'
    validate do
      if self[:db_name].nil?
        fail('The Access ID is a compulsory to change PeopleSoft passwords')
      end
      if self[:db_type].nil?
        fail('The Access password is a compulsory to change PeopleSoft passwords')
      end
      if self[:db_access_id].nil?
        fail('The Access password is a compulsory to change PeopleSoft passwords')
      end
      if self[:db_access_pwd].nil?
        fail('The Access password is a compulsory to change PeopleSoft passwords')
      end
      if self[:change_password].nil?
        fail('The Access password is a compulsory to change PeopleSoft passwords')
      end

    end
    newparam(:db_name) do
    end
    newparam(:db_type) do
    end
    newparam(:db_access_id) do
    end
    newparam(:db_access_pwd) do
    end
    newparam(:db_admin_pwd) do
    end
    newparam(:db_connect_id) do
    end
    newparam(:db_connect_pwd) do
    end
    newparam(:db_opr_id) do
    end
    newparam(:db_opr_pwd) do
    end
    newparam(:db_server_name) do
    end
    newparam (:os_user) do
    end
    newparam(:ps_home) do
    end
    newparam(:oracle_client_home) do
    end
    newparam(:pia_site_list) do
    end
    newproperty(:pia_domain_number) do
    end

    newproperty(:change_password) do
    end

    newproperty(:pia_domain_array, :array_matching => :all) do
    end
    parameter :domain_name
    newproperty(:returns, :array_matching => :all, :event => :change_password) do
      include Puppet::Util::Execution
      munge do |value|
        value.to_s
      end

      def event_name
        :change_password
      end

      defaultto "0"

      attr_reader :output

      # Actually execute the DMS.
      def sync
        provider.change_psft_passwords
      end
    end
  end
end
