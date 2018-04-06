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
  Type.newtype(:pt_deploy_cloudmanager) do
    include EasyType

    @doc = "Manages the state of PeopleTools Cloud Manager."

    ensurable

    newparam(:opc_user_name) do
      desc "The OPC user name."
    end

    newproperty(:prcs_domain_name) do
      desc "The PRCS Domain name"
    end

    newproperty(:ps_dpk_location) do
      desc "DPK directory"
    end

    newproperty(:opc_domain_name) do
      desc "The OPC domaine name"
    end

    parameter :os_user
    parameter :ps_home_dir
    parameter :ps_cfg_home_dir
    parameter :ps_app_home_dir
    parameter :deploy_user
    parameter :deploy_user_group
    newparam(:name)

  end
end
