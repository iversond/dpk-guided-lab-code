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

require 'puppet/provider/deployarchive'
require 'fileutils'
require 'pt_deploy_utils/validations'
require 'pt_deploy_utils/database'

Puppet::Type.type(:pt_deploy_oracleclient).provide :deploy_oracleclient,
                  :parent => Puppet::Provider::DeployArchive do
  include ::PtDeployUtils::Validations
  include ::PtDeployUtils::Database

  if Facter.value(:osfamily) != 'windows'
    commands :extract_cmd =>  'tar'
  end

  mk_resource_methods

  private

  def validate_parameters()
    if Facter.value(:osfamily) != 'windows'
      super()

      deploy_user = resource[:deploy_user]
      deploy_group = resource[:deploy_user_group]
      inventory_location = resource[:oracle_inventory_location]
      inventory_user = resource[:oracle_inventory_user]
      inventory_group = resource[:oracle_inventory_group]

      validate_oracle_inventory_permissions(inventory_location,
                                            inventory_user, inventory_group,
                                            deploy_user, deploy_group)
    end
  end

  def post_create()
    # create the oracle inventory if needed
    inventory_location = resource[:oracle_inventory_location]
    inventory_user = resource[:oracle_inventory_user]
    inventory_group = resource[:oracle_inventory_group]
    inventory_location = checkcreate_oracle_inventory(inventory_location,
                                 inventory_user, inventory_group)

    # clone the oracle home
    oracle_home = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    deploy_group = resource[:deploy_user_group]

    if Facter.value(:osfamily) == 'windows'
      #TODO: need to check why the chmod_R is not working
      #perm_cmd = "icacls #{oracle_home} /grant Administrators:F /T > NUL"
      perm_cmd = "icacls #{oracle_home} /grant *S-1-5-32-544:F /T > NUL"
	  
      system(perm_cmd)
      if $? == 0
        Puppet.debug('Oracle client home permissions updated successfully')
      else
        clean_installation('client', oracle_home, inventory_location)
        raise Puppet::ExecutionFailure, "Oracle client home permissions update failed"
      end
    end
    clone_oracle_home(oracle_home, deploy_user, deploy_group,
                      inventory_location, 'client')

  end


  def pre_delete()
    oracle_home = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    inventory_location = resource[:oracle_inventory_location]

    # deinstall oracle client home
    deinstall_oracle_client_home(oracle_home, deploy_user, inventory_location)

    oracle_base = File.dirname(oracle_home)
    FileUtils.rm_rf(oracle_base)

    @property_hash[:ensure] = :absent

  end
end
