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
class pt_profile::pt_oracleserver {
  notify { "Applying pt_profile::pt_oracleserver": }

  # Hiera lookups
  $ensure                      = hiera('ensure')
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type                    = hiera('env_type')
  if !($env_type in [ 'fulltier', 'dbtier']) {
    fail('The pt_oracleserver profile can only be applied to env_type of fulltier or dbtier')
  }
  $tools_archive_location      = hiera('archive_location')

  if $::osfamily != 'windows' {
    $users_hiera               = hiera('users')
    $psft_user                 = $users_hiera['psft_user']
    if ($psft_user) and ($psft_user != '') {
      $psft_install_user_name  = $psft_user['name']
      $psft_install_group_name = $psft_user['gid']

      $oracle_install_user       = $users_hiera['oracle_user']
      if ($oracle_install_user) and ($oracle_install_user != '') {
        $oracle_install_user_name  = $oracle_install_user['name']
        $oracle_install_group_name = $oracle_install_user['gid']
      }
      else {
        $oracle_install_user_name  = $psft_install_user_name
        $oracle_install_group_name = $psft_install_group_name
      }
    }
    else {
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
  $oracleserver_hiera    = hiera('oracle_server')
  $oracleserver_location = $oracleserver_hiera['location']
  $oracleserver_listener_port = $oracleserver_hiera['listener_port']
  $oracleserver_listener_name = $oracleserver_hiera['listener_name']
  $oracleserver_remove        = $oracleserver_hiera['remove']
  if $oracleserver_remove == undef {
    $remove = true
  }
  else {
    $remove = str2bool($oracleserver_remove)
  }

  if $ensure == present {
    $db_location = hiera('db_location')
    notice ("DB location is  ${db_location}")

    include ::pt_setup::psft_filesystem
    realize ( ::File[$db_location] )

    $oracleserver_archive_file   = get_matched_file($tools_archive_location,
                                                  'oracleserver')
    if $oracleserver_archive_file == '' {
      fail("Unable to locate archive (tgz) file for Oracle Server in ${tools_archive_location}")
    }
    $redeploy = hiera('redeploy', false)
  }
  $oracleserver_patches = hiera('oracle_server_patches', '')
  if ($oracleserver_patches) and ($oracleserver_patches != '') {
    notice ("Oracle Server patches exists")
    $oracleserver_patches_list = values($oracleserver_patches)
  }
  else {
    notice ("Oracle Server patches do not exist")
    $oracleserver_patches_list = undef
  }
  pt_deploy_oracleserver { "oracleserver":
    ensure                    => $ensure,
    deploy_user               => $oracle_install_user_name,
    deploy_user_group         => $oracle_install_group_name,
    archive_file              => $oracleserver_archive_file,
    deploy_location           => $oracleserver_location,
    oracle_inventory_location => $inventory_location,
    oracle_inventory_user     => $oracle_install_user_name,
    oracle_inventory_group    => $oracle_install_group_name,
    listener_port             => $oracleserver_listener_port,
    listener_name             => $oracleserver_listener_name,
    redeploy                  => $redeploy,
    remove                    => $remove,
    patch_list                => $oracleserver_patches_list,
  }
}
