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
class pt_profile::pt_app_deployment {
 notify { "Applying pt_profile::pt_app_deployment": }

  # Hiera lookups
  $ensure                   = hiera('ensure')
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type                 = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_app_deployment profile can only be applied to env_type of fulltier or midtier')
  }
  $app_archive_location     = hiera('archive_location')

  if $::osfamily != 'windows' {
    $users_hiera            = hiera('users')

    $psft_user              = $users_hiera['psft_user']
    if ($psft_user) and ($psft_user != '') {
      $app_install_user_name   = $psft_user['name']
      $app_install_group_name  = $psft_user['gid']
    }
    else {
      $app_install_user     = $users_hiera['app_install_user']
      if $app_install_user == undef {
        fail("app_install_user entry is not specified in 'users' hash table in the YAML file")
      }
      $app_install_user_name  = $app_install_user['name']
      $app_install_group_name = $app_install_user['gid']
    }
  }
  $deploy_apphome_only = hiera('deploy_apphome_only', false)

  $ps_apphome_hiera    = hiera('ps_app_home')
  $db_type             = $ps_apphome_hiera['db_type']
  $ps_apphome_location = $ps_apphome_hiera['location']
  notice ("PS App Home location is ${ps_apphome_location}")

  $ps_apphome_remove_value    = $ps_apphome_hiera['remove']
  if $ps_apphome_remove_value == undef {
    $ps_apphome_remove = true
  }
  else {
    $ps_apphome_remove = str2bool($ps_apphome_remove_value)
  }
  notice ("PS App Home remove flag ${ps_apphome_remove}")

  if $deploy_apphome_only == false {
    $install_type_hiera = hiera('install_type')
    $db_type_hiera      = hiera('db_type')

    if ($install_type_hiera == 'PUM') and ($db_type_hiera == 'DEMO') {
    $pi_home_hiera        = hiera('pi_home', '')
    if ($pi_home_hiera) and ($pi_home_hiera != '') {
      $pi_home_location     = $pi_home_hiera['location']
      notice ("PS App PI Home location is ${pi_home_location}")

      $pi_home_remove_value = $pi_home_hiera['remove']
      if $pi_home_remove_value == undef {
        $pi_home_remove     = true
      }
      else {
        $pi_home_remove     = str2bool($pi_home_remove_value)
      }
    }
    else {
      $pi_home_remove = true
    }
    notice ("PS PI Home remove flag ${ps_apphome_remove}")
    }
    $ps_custhome_hiera      = hiera('ps_cust_home', '')
    if ($ps_custhome_hiera) and ($ps_custhome_hiera != '') {
      $ps_custhome_location = $ps_custhome_hiera['location']
      notice ("PS Cust Home location is ${ps_custhome_location}")

      $ps_custhome_remove_value = $ps_custhome_hiera['remove']
      if $ps_custhome_remove_value == undef {
        $ps_custhome_remove = true
      }
      else {
        $ps_custhome_remove = str2bool($ps_custhome_remove_value)
      }
    }
    else {
      $ps_custhome_remove = true
    }
    notice ("PS Cust Home remove flag ${ps_custhome_remove}")
  }
  $redeploy = hiera('redeploy', false)
  class { '::pt_setup::app_deployment':
    ensure               => $ensure,
    deploy_apphome_only  => $deploy_apphome_only,
    app_archive_location => $app_archive_location,
    app_install_user     => $app_install_user_name,
    app_install_group    => $app_install_group_name,
    db_type              => $db_type,
    ps_apphome_location  => $ps_apphome_location,
    ps_apphome_remove    => $ps_apphome_remove,
    pi_home_location     => $pi_home_location,
    pi_home_remove       => $pi_home_remove,
    ps_custhome_location => $ps_custhome_location,
    ps_custhome_remove   => $ps_custhome_remove,
    redeploy             => $redeploy,
  }
  contain ::pt_setup::app_deployment
}
