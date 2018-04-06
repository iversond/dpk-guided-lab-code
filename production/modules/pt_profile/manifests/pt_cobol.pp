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
class pt_profile::pt_cobol {
  notify { "Applying pt_profile::pt_cobol": }

  $env_type = hiera('env_type')
  if $env_type == 'dbtier' {
    fail('The pt_cobol profile can only be applied to midtier and fulltier env_type')
  }
  $pshome_hiera       = hiera('ps_home')
  $pshome_location    = $pshome_hiera['location']

  $psapphome_hiera = hiera('ps_app_home', '')
  if ($psapphome_hiera) and ($psapphome_hiera != '') {
    $psapphome_location = $psapphome_hiera['location']
  }

  $pscusthome_hiera = hiera('ps_cust_home', '')
  if ($pscusthome_hiera) and ($pscusthome_hiera != '') {
    $pscusthome_location = $pscusthome_hiera['location']
  }

  $cobol_hiera        = hiera('cobol')
  $cobol_location     = $cobol_hiera['location']

  if $::osfamily != 'windows' {
    $users_hiera        = hiera('users')

    $psft_user = $users_hiera['psft_user']
    if ($psft_user) and ($psft_user != '') {
      $tools_install_user = $psft_user['name']
      $app_install_user   = $psft_user['name']
      $psft_runtime_user  = $psft_user['name']
    }
    else {
      $tools_install_user_hiera = $users_hiera['tools_install_user']
      if $tools_install_user_hiera == undef {
        fail("tools_install_user entry is not specified in 'users' hash table in the YAML file")
      }
      $tools_install_user = $tools_install_user_hiera['name']
      $app_install_user_hiera  = $users_hiera['app_install_user']
      if $app_install_user_hiera == undef {
        fail("app_install_user entry is not specified in 'users' hash table in the YAML file")
      }
      $app_install_user = $app_install_user_hiera['name']
      $psft_runtime_user_hiera = $users_hiera['psft_runtime_user']
      if $psft_runtime_user_hiera == undef {
        fail("psft_runtime_user entry is not specified in 'users' hash table in the YAML file")
      }
      $psft_runtime_user = $psft_runtime_user_hiera['name']
    }
  }
  notify { "Compiling and Linking Cobol source": }

  pt_compile_cobol { 'cobol':
    action             => compile,
    ps_home_dir        => $pshome_location,
    ps_app_home_dir    => $psapphome_location,
    ps_cust_home_dir   => $pscusthome_location,
    cobol_home_dir     => $cobol_location,
    ps_home_owner      => $tools_install_user,
    ps_app_home_owner  => $app_install_user,
    ps_cust_home_owner => $psft_runtime_user,
  }
}
