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
  Type.newtype(:pt_deploy_oracleclient) do
    include EasyType
    include ::PtDeployUtils::Validations

    @doc = "This type manages the deployment of an Oracle client component.
      For deploying an Oracle client, an archive file containing the
      pre-installed bits of the Oracle client along with the deployment
      location should be specified.

      Note: If the node is running on a Unix platform and does not have an
      Oracle central inventory setup, Oracle inventory location along with
      the Oracle user and group information should be provided to deploy
      the Oracle client component.

      Note: On Unix platforms, deployment user and group information should
      also be provided."

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

            # check oracle inventory related validations
            inventory_location = self[:oracle_inventory_location]
            inventory_user = self[:oracle_inventory_user]
            inventory_group = self[:oracle_inventory_group]

            validate_oracle_inventory(inventory_location,
                                      inventory_user, inventory_group)
          end
        elsif (self[:ensure] == :absent) and
              (Facter.value(:osfamily) != 'windows')
          if self[:deploy_user].nil?
            fail("deploy_user attribute should be specified.")
          end
        end
        if self[:deploy_location].nil?
          fail("deploy_location attribute should be specified.")
        end
      end

      ensurable

      parameter :name
      parameter :archive_file
      parameter :deploy_location
      parameter :deploy_user
      parameter :deploy_user_group
      parameter :oracle_inventory_location
      parameter :oracle_inventory_user
      parameter :oracle_inventory_group
      parameter :redeploy
      parameter :remove
      parameter :patch_list
  end
end
