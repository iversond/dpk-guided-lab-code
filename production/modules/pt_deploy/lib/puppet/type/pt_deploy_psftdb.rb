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

require 'easy_type'
require 'pt_deploy_utils/validations'
require 'puppet/parameter/boolean'

module Puppet
  Type.newtype(:pt_deploy_psftdb) do
    include EasyType
    include ::PtDeployUtils::Validations

    @doc = "This type manages the deployment of PeoleSoft database.
      The database is pre-nstalled and packaged into a tgz archive file.
      This type extract this tgz archive into the specified deployment
      directory."

    validate do
      if self[:ensure] == :present
        if self[:archive_file].nil?
          fail("archive_file attribute should be specified.")
        end

        # make sure the deploy user and group is specified, if the os family
        # is not windows
        if Facter.value(:osfamily) != 'windows'
          user_name = self[:deploy_user]
          user_group = self[:deploy_user_group]

          validate_user_and_group(user_name, user_group)
        end
      end
      if self[:deploy_location].nil?
        fail("deploy_location attribute should be specified.")
      end
    end

    ensurable

    newparam(:database_name, :namevar => true) do
      desc "Specify the name of the database instance"

      validate do |value|
        Puppet.debug("Validating database name: #{value}")
        if value.match(/^[A-Z][A-Za-z0-9]{0,7}$/).nil?
          fail("Database instance name must be at most 8 " +
               "alphanumeric characters with first character an " +
               "Uppercase alphabet.")
        end
      end
    end

    parameter :archive_file
    parameter :deploy_location
    parameter :deploy_user
    parameter :deploy_user_group
    parameter :redeploy
  end
end
