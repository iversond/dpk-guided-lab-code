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
#  Copyright (C) 1988, 2015, Oracle and/or its affiliates.
#  All Rights Reserved.
# ***************************************************************

require 'pathname'
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent)
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent.parent.parent + 'easy_type' + 'lib')

require 'fileutils'
require 'easy_type'

module Puppet
  Type.newtype(:pt_cm_fileserver_config) do
    include EasyType

    @doc = "Manages the state of PeopleTools Cloud Manager File Server."

    ensurable

    newparam(:fileserver_mount_path) do
      desc "The Cloud Manager mount directory used for mounting the File Server."
    end

    newproperty(:fileserver_hostname) do
      desc "The File Server hostname"
    end

    newproperty(:fileserver_dpk_path) do
      desc "The DPK path in File Server, which is used to mount to Cloud Manager"
    end

    newparam(:fileserver_settings, :array_matching => :all) do
      desc "The File server settings used for sync data"

      validate do |values|

        values = [values] unless values.is_a? Array
        #Puppet.debug("Profile values: #{values.inspect}")
        raise ArgumentError,
          "Key/value pairs must be separated by an =" unless values[0].include?("=")
      end

      munge do |values|
        fileserver_hash = {}

        values = [values] unless values.is_a? Array
        values.each do |value|
          fileserver_hash[value.split('=')[0].strip.to_sym] =
                    value.split('=')[1].strip
        end
        if provider.respond_to?(:fileserver_hash=)
          provider.fileserver_hash=(fileserver_hash)
        end
        return fileserver_hash
       end
    end

    newparam(:name)
    parameter :ps_app_home_dir

  end
end

