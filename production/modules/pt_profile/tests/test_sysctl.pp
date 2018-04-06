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
$ensure = hiera('ensure')
$env_type = hiera('env_type')
notify {"\nEnv type: ${env_type}":}
$groups_hiera = hiera('groups')
$users_hiera = hiera('users')

if $facts['kernel'] == 'Linux' {
  notify {"\nLinux kernel":}
  notify {"\nEnsure ${ensure}":}
  if ($env_type == 'midtier') or ($env_type == 'both') {
    $psft_runtime_group      = $groups_hiera['psft_runtime_group']
    $psft_runtime_group_name = $psft_runtime_group['name']
    $app_install_group       = $groups_hiera['app_install_group']
    $app_install_group_name  = $app_install_group['name']

    $group_list               = any2array($psft_runtime_group_name,
                                         $app_install_group_name)
    if $group_list {
      $sysctl_group_hiera  = hiera('sysctl')
      $group_ulimits = $sysctl_group_hiera['group']
      notify {"\nUpdating group ulimits":}

      $group_list.each |$group| {
        ::pt_profile::pt_system::ulimit { "@${group}":
          ensure          => $ensure,
          domain_name     => "@${group}",
          ulimit_settings => $group_ulimits,
        }
      }
    }
  }
  if ($env_type == 'dbtier') or ($env_type == 'both') {
    $oracle_user      = $users_hiera['oracle_user']
    $oracle_user_name = $oracle_user['name']
    $user_list        = any2array($oracle_user_name)

    if $user_list {
      $sysctl_user_hiera = hiera('sysctl')
      $user_ulimits = $sysctl_user_hiera['user']

      notify {"\nUpdating user ulimits":}
      $user_list.each |$user| {
        ::pt_profile::pt_system::ulimit { "${user}":
          ensure          => $ensure,
          domain_name     => $user,
          ulimit_settings => $user_limits,
        }
      }
    }
  }
}


