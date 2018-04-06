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
 *  Copyright (C) 1988, 2015, Oracle and/or its affiliates.
 *  All Rights Reserved.
 * ***************************************************************
 */
class pt_profile::pt_cloudmanager_deployment {
  notify { "Applying pt_profile::pt_cloudmanager_deployment": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_cloudmanager_deployment profile can only be applied to env_type of fulltier or midtier')
  }
  $pshome_hiera       = hiera('ps_home')
  $prcs_domain_name   = hiera('prcs_domain_name')
  $pshome_location    = $pshome_hiera['location']

  $psapphome_hiera = hiera('ps_app_home', '')
  if ($psapphome_hiera) and ($psapphome_hiera != '') {
    $psapphome_location = $psapphome_hiera['location']
  }

  if $::osfamily != 'windows' {
    $users_hiera               = hiera('users')

    $psft_user                 = $users_hiera['psft_user']
    if ($psft_user) and ($psft_user != '') {
      $tools_install_user_name   = $psft_user['name']
      $tools_install_group_name  = $psft_user['gid']
    }
    else {
      $tools_install_user        = $users_hiera['tools_install_user']
      if $tools_install_user == undef {
        fail("tools_install_user entry is not specified in 'users' hash table in the YAML file")
      }
      $tools_install_user_name   = $tools_install_user['name']
      $tools_install_group_name  = $tools_install_user['gid']
    }
  }
  $ps_dpk_location = hiera('dpk_location')

  $cloud_manager_settings_tag = 'cloud_manager_settings'
  $cloud_manager_settings = hiera("${cloud_manager_settings_tag}")

  $os_user            = $cloud_manager_settings['os_user']
  $ps_cfg_home_dir    = $cloud_manager_settings['ps_cfg_home_dir']
  $opc_user_name      = $cloud_manager_settings['opc_user_name']
  $opc_domain_name    = $cloud_manager_settings['opc_domain_name']

  class { '::pt_setup::cloudmanager_deployment':
    ensure                => $ensure,
    tools_install_user    => $tools_install_user_name,
    tools_install_group   => $tools_install_group_name,
    os_user               => $os_user,
    ps_home_dir           => $pshome_location,
    ps_app_home_dir       => $psapphome_location,
    ps_cfg_home_dir       => $ps_cfg_home_dir,
    prcs_domain_name      => $prcs_domain_name,
    opc_user_name         => $opc_user_name,
    opc_domain_name       => $opc_domain_name,
    ps_dpk_location       => $ps_dpk_location,
  }
  contain ::pt_setup::cloudmanager_deployment
}
