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
  Type.newtype(:pt_cloud_manager_patch) do
    include EasyType

    @doc = "Manages the state of PeopleTools Cloud Manager Patching operation."

    ensurable

    newparam(:patch_type) do
      desc "Patching File type - File/Directory."
    end

    newproperty(:patch_target) do
      desc "Patching target location"
    end

    newproperty(:patch_source) do
      desc "file source for patching"
    end

    newproperty(:patch_mode) do
      desc "Target file permission"
    end


    parameter :os_user
    newparam(:name)

  end
end

