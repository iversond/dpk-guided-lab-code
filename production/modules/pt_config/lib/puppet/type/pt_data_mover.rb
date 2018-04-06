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
  Type.newtype(:pt_data_mover) do
    include EasyType
    include ::PtCompUtils::Validations

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
      if self[:db_server_name].nil?
        fail('The Access password is a compulsory to change PeopleSoft passwords')
      end

    end
    newparam(:db_name, :namevar => true) do
    end
    newparam(:db_type) do
    end
    newparam(:db_access_id) do
    end
    newparam(:db_access_pwd) do
    end
    newparam(:db_connect_id) do
    end
    newparam(:db_connect_pwd) do
    end
    newparam(:db_server_name) do
    end
    newparam (:os_user) do
    end
    newparam(:ps_home) do
    end

    newproperty(:dms_location) do
    end

    newproperty(:returns, :array_matching => :all, :event => :executed_dms) do |property|
      include Puppet::Util::Execution
      munge do |value|
        value.to_s
      end

      def event_name
        :executed_dms
      end

      defaultto "0"

      attr_reader :output

      # Actually execute the DMS.
      def sync
        # event = :executed_dms
        @output, @status = provider.run_dms_script(:dms_content_array)
        print @output
        print @status
      end
    end
  end
end
