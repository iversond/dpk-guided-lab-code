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
# Define:
#
#
define pt_setup::user_environment (
  $ensure             = present,
  $os_user            = undef,
  $os_user_home_dir   = undef,
  $ps_home_dir        = undef,
  $ps_cfg_home_dir    = undef,
  $ps_app_home_dir    = undef,
  $ps_cust_home_dir   = undef,
  $oracle_home_dir    = undef,
  $tuxedo_home_dir    = undef,
  $tns_file_dir       = undef,
  $db2_sqllib_dir     = undef,
  $cobol_home_dir     = undef,
  ) {
  include ::pt_setup::params

  if $::osfamily == 'windows' {
    if $ensure == present {
      $ps_home_dir_norm     = normalize_path($ps_home_dir)
      $ps_cfg_home_dir_norm = normalize_path($ps_cfg_home_dir)

      if $tns_file_dir != undef {
        $tns_file_dir_norm = normalize_path($tns_file_dir)
        # set the TNS_ADMIN environment varaible
        exec { 'tns_admin_env':
          command => "$env_comspec /c setx TNS_ADMIN \"${tns_file_dir_norm}\" /M",
        }
      }
      else {
        exec { 'tns_admin_env':
          command => "$env_comspec /c setx TNS_ADMIN \"\" /M",
        }
      }
      # set the PS_HOME, PS_CFG_HOME, PS_APP_HOME, PS_CUST_HOME environment variables
      exec { 'ps_home_env':
        command => "$env_comspec /c setx PS_HOME \"${ps_home_dir_norm}\" /M",
      }
      exec { 'ps_cfg_home_env':
        command => "$env_comspec /c setx PS_CFG_HOME \"${ps_cfg_home_dir_norm}\" /M",
      }
      if $ps_app_home_dir != undef {
        $ps_app_home_dir_norm = normalize_path($ps_app_home_dir)
        exec { 'ps_app_home_env':
          command => "$env_comspec /c setx PS_APP_HOME \"${ps_app_home_dir_norm}\" /M",
        }
      }
      else {
        exec { 'ps_app_home_dir_env':
          command => "$env_comspec /c setx PS_APP_HOME \"\" /M",
        }
      }
      if $ps_cust_home_dir != undef {
        $ps_cust_home_dir_norm = normalize_path($ps_cust_home_dir)
        exec { 'ps_cust_home_env':
          command => "$env_comspec /c setx PS_CUST_HOME \"${ps_cust_home_dir_norm}\" /M",
        }
      }
      else {
        exec { 'ps_cust_home_dir_env':
          command => "$env_comspec /c setx PS_CUST_HOME \"\" /M",
        }
      }
    }
    elsif $ensure == absent {
      # remove the TNS_ADMIN environment variable
      exec { 'tns_admin_env':
        command => "$env_comspec /c setx TNS_ADMIN \"\" /M",
      }
      # remove the PS_HOME, PS_CFG_HOME, PS_APP_HOME, PS_CUST_HOME environment variables
      exec { 'ps_home_dir_env':
        command => "$env_comspec /c setx PS_HOME \"\" /M",
      }
      exec { 'ps_cfg_home_dir_env':
        command => "$env_comspec /c setx PS_CFG_HOME \"\" /M",
      }
      exec { 'ps_app_home_dir_env':
        command => "$env_comspec /c setx PS_APP_HOME \"\" /M",
      }
      exec { 'ps_cust_home_dir_env':
        command => "$env_comspec /c setx PS_CUST_HOME \"\" /M",
      }
    }
  }
  else {
    if $ensure == present {
      if $os_user_home_dir {
        $user_home_dir = $os_user_home_dir
      }
      else {
        $user_home_dir = "${::pt_setup::params::user_home_dir}/${os_user}"
      }
      $kernel_val = downcase($::kernel)
      file { $title:
        ensure  => $ensure,
        path    => "${user_home_dir}/${::pt_setup::params::user_profile_file}",
        content => template("pt_setup/${kernel_val}_user_environment.erb"),
      }
    }
  }
}
