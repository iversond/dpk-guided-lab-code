/*
 * ***************************************************************
 *  This software and related documentation are provided under a
 *  license agreement containing restrictions on use and
 *  disclosure and are protected by intellectual property
 *  laws. Except as expressly permitted in your license agreement
 *  or allowed by law, you may not use, copy, reproduce,
 *  translate, broadcast, modify, license, transmit, distribute,
 *  exhibit, perform, publish or display any part, in any form or
 *  by any means. Reverse engineering, disassembly, or
 *  decompilation of this software, unless required by law for
 *  interoperability, is prohibited.
 *  The information contained herein is subject to change without
 *  notice and is not warranted to be error-free. If you find any
 *  errors, please report them to us in writing.
 *
 *  Copyright (C) 1988, 2017, Oracle and/or its affiliates.
 *  All Rights Reserved.
 * ***************************************************************
 */
class pt_profile::pt_tools_deployment {
  notify { "Applying pt_profile::pt_tools_deployment": }

  ## Hiera lookups
  $ensure                    = hiera('ensure')
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type                  = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_tools_deployment profile can only be applied to env_type of fulltier or midtier')
  }
  $tools_archive_location      = hiera('archive_location')
  if $::osfamily != 'windows' {
    $users_hiera               = hiera('users')
      $psft_user                 = $users_hiera['psft_user']

    if ($psft_user) and ($psft_user != '') {
      $tools_install_user_name   = $psft_user['name']
      $tools_install_group_name  = $psft_user['gid']

      $oracle_install_user_name  = $psft_user['name']
      $oracle_install_group_name = $psft_user['gid']
    }
    else {
      $tools_install_user        = $users_hiera['tools_install_user']
      if $tools_install_user == undef {
        fail("tools_install_user entry is not specified in 'users' hash table in the YAML file")
      }
      $tools_install_user_name   = $tools_install_user['name']
      $tools_install_group_name  = $tools_install_user['gid']

    $oracle_install_user       = $users_hiera['oracle_user']
    if $oracle_install_user == undef {
      fail("oracle_user entry is not specified in 'users' hash table in the YAML file")
    }
    $oracle_install_user_name  = $oracle_install_user['name']
    $oracle_install_group_name = $oracle_install_user['gid']
    }
    $inventory_hiera           = hiera('inventory')
    $inventory_location        = $inventory_hiera['location']
    notice ("Inventory location is  ${inventory_location}")

  }
  $deploy_pshome_only    = hiera('deploy_pshome_only', false)

  $pshome_hiera          = hiera('ps_home')
  $db_type               = $pshome_hiera['db_type']
  $pshome_location       = $pshome_hiera['location']
  notice ("PS Home location is  ${pshome_location}")

  $pshome_remove_value  = $pshome_hiera['remove']
  if $pshome_remove_value == undef {
    $pshome_remove        = true
  }
  else {
  $pshome_remove        = str2bool($pshome_remove_value)
  }
  notice ("PS Home remove is ${pshome_remove}")

  if $deploy_pshome_only == false {
    if $env_type == 'midtier' {
      $db_platform = hiera('db_platform')
      if $db_platform == 'ORACLE' {
        $oracleclient_hiera    = hiera('oracle_client')
        $oracleclient_location = $oracleclient_hiera['location']

        $oracleclient_remove_value  = $oracleclient_hiera['remove']
        if $oracleclient_remove_value == undef {
          $oracleclient_remove = true
        }
        else {
          $oracleclient_remove = str2bool($oracleclient_remove_value)
        }
        notice ("Oracle client remove is ${oracleclient_remove}")
      }
    }
    $jdk_hiera             = hiera('jdk')
    $jdk_location          = $jdk_hiera['location']
    $jdk_remove_value      = $jdk_hiera['remove']
    if $jdk_remove_value == undef {
      $jdk_remove        = true
    }
    else {
    $jdk_remove            = str2bool($jdk_remove_value)
    }
    notice ("JDK remove is ${jdk_remove}")

    $weblogic_hiera        = hiera('weblogic')
    $weblogic_location     = $weblogic_hiera['location']
    $weblogic_remove_value = $weblogic_hiera['remove']
    if $weblogic_remove_value == undef {
      $weblogic_remove        = true
    }
    else {
    $weblogic_remove       = str2bool($weblogic_remove_value)
    }
    notice ("Weblogic remove is ${weblogic_remove}")

    $tuxedo_hiera          = hiera('tuxedo')
    $tuxedo_location       = $tuxedo_hiera['location']
    $tuxedo_remove_value   = $tuxedo_hiera['remove']
    if $tuxedo_remove_value == undef {
      $tuxedo_remove        = true
    }
    else {
    $tuxedo_remove         = str2bool($tuxedo_remove_value)
    }
    notice ("Tuxedo remove is ${tuxedo_remove}")

    $ohs_hiera             = hiera('setup_ohs', false)
    if $ohs_hiera == true  {
      $ohs_comp_hiera      = hiera('ohs')
      $ohs_location        = $ohs_comp_hiera['location']
      $ohs_remove_value    = $ohs_comp_hiera['remove']
      if $ohs_remove_value == undef {
        $ohs_remove        = true
      }
      else {
      $ohs_remove          = str2bool($ohs_remove_value)
      }
      notice ("OHS remove is ${ohs_remove}")
    }
  }
  $redeploy = hiera('redeploy', false)
  class { '::pt_setup::tools_deployment':
    ensure                 => $ensure,
    deploy_pshome_only     => $deploy_pshome_only,
    tools_archive_location => $tools_archive_location,
    tools_install_user     => $tools_install_user_name,
    tools_install_group    => $tools_install_group_name,
    oracle_install_user    => $oracle_install_user_name,
    oracle_install_group   => $oracle_install_group_name,
    db_type                => $db_type,
    pshome_location        => $pshome_location,
    pshome_remove          => $pshome_remove,
    inventory_location     => $inventory_location,
    oracleclient_location  => $oracleclient_location,
    oracleclient_remove    => $oracleclient_remove,
    jdk_location           => $jdk_location,
    jdk_remove             => $jdk_remove,
    weblogic_location      => $weblogic_location,
    weblogic_remove        => $weblogic_remove,
    tuxedo_location        => $tuxedo_location,
    tuxedo_remove          => $tuxedo_remove,
    ohs_location           => $ohs_location,
    ohs_remove             => $ohs_remove,
    redeploy               => $redeploy,
  }
  contain ::pt_setup::tools_deployment
}
