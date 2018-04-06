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
#
# This class sets up the users required by the PeopleSoft
# runtime system
#
class pt_profile::pt_system::users (
  $ensure     = 'present',
  $user_list  = undef,
) inherits ::pt_profile::pt_system::params {

  if $user_list {
    $user_list.each |$user_info| {
      $user_name = $user_info['name']
      $user_id   = $user_info['uid']

      $user_password = $user_info['password']
      if ($user_password) and ($user_password != '') {
        notice ("Password value provided")
        $user_password_give = true
      $user_password_hash = password_hash($user_password)
      }
      else {
        notice ("Password value not provided")
        $user_password_give = false
      }

      if $ensure == present {
        $user_home_dir = $user_info['home_dir']
        if $user_home_dir != '' {
          $user_home = "${user_home_dir}"
        }
        else {
          $user_home = "${::pt_profile::pt_system::params::users_home}/${user_name}"
        }
        notify {"User ${user_name} home dir ${user_home}":}
        if $user_password_give == true {
          user { $user_name:
            ensure     => $ensure,
            uid        => $user_id,
            gid        => $user_info['gid'],
            groups     => $user_info['groups'],
            expiry     => $user_info['expiry'],
            password   => $user_password_hash,
            home       => $user_home,
            managehome => true,
            shell      => $::pt_profile::pt_system::params::default_user_shell,
          } ->
          file { "${user_home}":
            mode       => '0755',
          }
          if $::kernel == 'Linux' {
            file { "${user_home}/.profile":
              ensure   => $ensure,
            } ->
            # set the password expiry to immediate
            exec { "chage -d 0 ${user_name}":
              path     => [ "/usr/bin/" ],
            }
          }
          if $::kernel == 'SunOS' {
            # set the password expiry to immediate
            exec { "passwd -x 0 ${user_name}":
              path     => [ "/bin/" ],
            }
          }
        }
        else {
          user { $user_name:
            ensure     => $ensure,
            uid        => $user_id,
            gid        => $user_info['gid'],
            groups     => $user_info['groups'],
            expiry     => $user_info['expiry'],
            home       => $user_home,
            managehome => true,
            shell      => $::pt_profile::pt_system::params::default_user_shell,
          } ->
          file { "${user_home}":
            mode       => '0755',
          }
          if $::kernel == 'Linux' {
            file { "${user_home}/.profile":
              ensure   => $ensure,
            }
          }
        }
      }
      elsif $ensure == absent {
        $user_remove = $user_info['remove']
        if $user_remove == false {
          notify {"User ${user_name} will not be removed":}
        }
        else {
          user { $user_name:
            ensure     => $ensure,
            managehome => true,
          }
        }
      }
      notify {"Ensure ${ensure} user ${user_name} with id ${user_id}":}
    }
  }
}
