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
class pt_profile::pt_system {
  if $::osfamily != 'windows' {
    $ensure = hiera('ensure')
    $env_type = hiera('env_type')
    notify { "Applying pt_profile::pt_system: ensure: ${ensure}": }
    notify { "PeopleSoft environment type: ${env_type}": }

    if !($env_type in [ 'fulltier', 'midtier', 'dbtier', 'es' ]) {
      fail('env_type parameter value must be fulltier, midtier, es or dbtier')
    }
    # check if samba setup is requested.If so make sure samba package is
    # installed on the machine
    $setup_samba = hiera('setup_samba')
    if $setup_samba == true {
      $samba_installed = $::samba_installed
      notify { "Samba installed: ${samba_installed}": }

      if "${samba_installed}" == "false" {
        fail("Samba OS package is not installed on the Host. Samba shares cannot be setup.
        Either set the setup_samba parameter value in Hiera YAML file to false or install
        Samba OS package on the Host.\n")
      }
    }
    if $ensure == present {
      # set the hostname of the machine to without domain name if the hostname
      # value returned is greater than 30 characters. This is to ensure that
      # Tuxedo doesn't barf
      $hostname = $::hostname
      exec { "hostname_update":
        command => "hostname ${hostname}",
        onlyif  => "test $(echo -n $::fqdn | wc -c) -gt 30",
        path    => [ "/usr/bin:/bin" ],
      }
    }
    $groups_hiera = hiera('groups')
    $group_list = values($groups_hiera)
    notify { "Hiera groups: ${group_list}": }

    $users_hiera = hiera('users')
    $user_list = values($users_hiera)
    # Commenting the next line and later we need to revoke with proper masking -water
    # notify { "Hiera users: ${user_list}": }

    class { '::pt_profile::pt_system::groups':
      ensure     => $ensure,
      group_list => $group_list,
    }

    class { '::pt_profile::pt_system::users':
      ensure     => $ensure,
      user_list  => $user_list,
    }
    contain ::pt_profile::pt_system::groups
    contain ::pt_profile::pt_system::users

    if $ensure == present {
      Class['::pt_profile::pt_system::groups'] ->
      Class['::pt_profile::pt_system::users']
    }
    elsif $ensure == absent {
      Class['::pt_profile::pt_system::users'] ->
      Class['::pt_profile::pt_system::groups']
    }
    else {
      fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
    }
    $setup_sysctl = hiera('setup_sysctl')
    if $setup_sysctl == true {
      $sysctl_settings  = hiera('sysctl')
      class { '::pt_profile::pt_system::sysctlconf':
        ensure          => $ensure,
        sysctl_settings => $sysctl_settings,
      }
      contain ::pt_profile::pt_system::sysctlconf
    }
    if ($::kernel == 'Linux') or ($::kernel == 'AIX') {
      if ($env_type == 'midtier') or ($env_type == 'fulltier') {
        $psft_group          = $groups_hiera['psft_group']
        if ($psft_group) and ($psft_group != '') {
          $psft_group_name   = $psft_group['name']
          $ulimit_group_list = any2array($psft_group_name)
        }
        else {
          $psft_runtime_group      = $groups_hiera['psft_runtime_group']
          if $psft_runtime_group == undef {
            fail("psft_runtime_group entry is not specified in 'group' hash table in the YAML file")
          }
          $psft_runtime_group_name = $psft_runtime_group['name']

          $app_install_group       = $groups_hiera['app_install_group']
          if $app_install_group == undef {
            fail("app_install_group entry is not specified in 'group' hash table in the YAML file")
          }
          $app_install_group_name  = $app_install_group['name']
          $ulimit_group_list       = any2array($psft_runtime_group_name, $app_install_group_name)
        }
        if $ulimit_group_list {
          $ulimit_group_hiera  = hiera('ulimit')
          $group_ulimits       = $ulimit_group_hiera['group']

          notify {"\nUpdating group ulimits":}

          $ulimit_group_list.each |$group| {
            ::pt_profile::pt_system::ulimit { "@${group}":
              ensure          => $ensure,
              domain_name     => "@${group}",
              ulimit_settings => $group_ulimits,
            }
          }
        }
      }
      if ($env_type == 'dbtier') or ($env_type == 'fulltier') {
        $psft_user = $users_hiera['psft_user']
        if ($psft_user) and ($psft_user != '') {
          notify {"\nUlimits already set":}
        }
        else {
          $oracle_user      = $users_hiera['oracle_user']
          if $oracle_user == undef {
            fail("oracle_user entry is not specified in 'users' hash table in the YAML file")
          }
          $oracle_user_name = $oracle_user['name']
          $ulimit_user_list = any2array($oracle_user_name)

          if $ulimit_user_list {
            $ulimit_user_hiera = hiera('ulimit')
            $user_ulimits = $ulimit_user_hiera['user']

            notify {"\nUpdating user ulimits":}

            $ulimit_user_list.each |$user| {
              ::pt_profile::pt_system::ulimit { "${user}":
                ensure          => $ensure,
                domain_name     => $user,
                ulimit_settings => $user_ulimits,
              }
            }
          }
        }
      }
      if ($::is_virtual == 'true') and ($::virtual == 'virtualbox') {
        class { '::pt_setup::psft_netupdate_service':
          ensure => $ensure,
        }
        contain ::pt_setup::psft_netupdate_service
      }
    }
  }
}
