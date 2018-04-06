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
class pt_profile::pt_psft_environment {
  notify { "Applying pt_profile::pt_psft_environment": }

  $ensure   = hiera('ensure', present)
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier', 'dbtier' ]) {
    fail('env_type parameter value must be fulltier, midtier or dbtier')
  }
  $pshome_hiera         = hiera('ps_home')
  $pshome_location      = $pshome_hiera['location']
  $pshome_db_type       = $pshome_hiera['db_type']
  $pshome_db_type_upper = upcase($pshome_db_type)

  if $::osfamily != 'windows' {
    $users_hiera = hiera('users')
  }

  if $pshome_db_type_upper == 'ORACLE' {
    # SETUP TNS_ADMIN VARIABLE IFF THE
    # USER DID NOT SELECT DEPLOY_ONLY
    $pshome_only           = hiera('deploy_pshome_only', false)
    $apphome_only          = hiera('deploy_apphome_only', false)
    if ($pshome_only == false) and ($apphome_only == false) {
       $tns_location          = hiera('tns_dir')
    }

    if $env_type == 'midtier' {
      $oracle_hiera        = hiera('oracle_client')
      $oracle_location     = $oracle_hiera['location']
      $oracle_tns_location = $tns_location
    }
    elsif ($env_type == 'fulltier') or ($env_type == 'dbtier') {
      $oracle_hiera        = hiera('oracle_server')
      $oracle_location     = $oracle_hiera['location']
      $oracle_tns_location = $tns_location
    }
    else {
      fail('env_type parameter value must be fulltier, midtier or dbtier')
    }
    # setup DB user 'oracle' environment
    if $::osfamily != 'windows' {
      $oracle_user_hiera    = $users_hiera['oracle_user']
      if ($oracle_user_hiera) and ($oracle_user_hiera != '') {
        $oracle_user          = $oracle_user_hiera['name']
        $oracle_user_home_dir = $oracle_user_hiera['home_dir']

        ::pt_setup::user_environment { "${oracle_user}_environment":
          ensure           => $ensure,
          os_user          => $oracle_user,
          os_user_home_dir => $oracle_user_home_dir,
          oracle_home_dir  => $oracle_location,
          tns_file_dir     => $oracle_tns_location,
        }
      }
    }
  }
  elsif ($pshome_db_type_upper == 'DB2ODBC') or ($pshome_db_type_upper == 'DB2UNIX') {
    if $env_type == 'midtier' {
      $db2_hiera           = hiera('db2_client')
      $db2_sqllib_location = $db2_hiera['sqllib_location']
    }
    else {
      fail("env_type parameter value ${env_type} is not supported for ${pshome_db_type_upper} \
           database type")
    }
  }
  elsif ($pshome_db_type_upper == 'MSSQL') {
    notice ("Database type is MSSQL, nothing to set for the user environment")
  }
  else {
    fail("DB platform ${pshome_db_type_upper} is not supported")
  }

  if $env_type != 'dbtier' {
      $tuxedo_hiera       = hiera('tuxedo')
      $tuxedo_location    = $tuxedo_hiera['location']

      $pscfg_location     = hiera('ps_config_home')

      $psapphome_hiera    = hiera('ps_app_home', '')
      if ($psapphome_hiera) and ($psapphome_hiera != '') {
        $psapphome_location = $psapphome_hiera['location']
      }

      $pscusthome_hiera   = hiera('ps_cust_home', '')
      if ($pscusthome_hiera) and ($pscusthome_hiera != '') {
        $pscusthome_location = $pscusthome_hiera['location']
      }

      $cobol_hiera        = hiera('cobol', '')
      if ($cobol_hiera) and ($cobol_hiera != '') {
        $cobol_location = $cobol_hiera['location']
      }
    if $::osfamily != 'windows' {
      # PeopleSoft single user
      $psft_single_installer = $users_hiera['psft_user']
      if ($psft_single_installer) and ($psft_single_installer != '') {
        $psft_single_user = $psft_single_installer['name']
        $psft_single_user_home = $psft_single_installer['home_dir']
        ::pt_setup::user_environment { "${psft_single_user}_environment":
          ensure           => $ensure,
          os_user          => $psft_single_user,
          os_user_home_dir => $psft_single_user_home,
          ps_home_dir      => $pshome_location,
          ps_cfg_home_dir  => $pscfg_location,
          ps_app_home_dir  => $psapphome_location,
          ps_cust_home_dir => $pscusthome_location,
          oracle_home_dir  => $oracle_location,
          tuxedo_home_dir  => $tuxedo_location,
          tns_file_dir     => $tns_location,
          db2_sqllib_dir   => $db2_sqllib_location,
          cobol_home_dir   => $cobol_location,
        }
      }
      else {
        # PeopleSoft runtime user
        $psft_runtime_installer = $users_hiera['psft_runtime_user']
        if ($psft_runtime_installer) and ($psft_runtime_installer != '') {
          $psft_runtime_user = $psft_runtime_installer['name']
          $psft_runtime_user_home = $psft_runtime_installer['home_dir']
          ::pt_setup::user_environment { "${psft_runtime_user}_environment":
            ensure           => $ensure,
            os_user          => $psft_runtime_user,
            os_user_home_dir => $psft_runtime_user_home,
            ps_home_dir      => $pshome_location,
            ps_cfg_home_dir  => $pscfg_location,
            ps_app_home_dir  => $psapphome_location,
            ps_cust_home_dir => $pscusthome_location,
            oracle_home_dir  => $oracle_location,
            tuxedo_home_dir  => $tuxedo_location,
            tns_file_dir     => $tns_location,
            db2_sqllib_dir   => $db2_sqllib_location,
            cobol_home_dir   => $cobol_location,
          }
        }
        else {
          fail("psft_runtime_user entry is not specified in 'users' hash table in the YAML file")
        }
        # peoplesoft Tools install user
        $psft_tools_installer = $users_hiera['tools_install_user']
        if ($psft_tools_installer) and ($psft_tools_installer != '') {
          $psft_tools_install_user = $psft_tools_installer['name']
          $psft_tools_install_user_home = $psft_tools_installer['home_dir']
          ::pt_setup::user_environment { "${psft_tools_install_user}_environment":
            ensure           => $ensure,
            os_user          => $psft_tools_install_user,
            os_user_home_dir => $psft_tools_install_user_home,
            ps_home_dir      => $pshome_location,
            oracle_home_dir  => $oracle_location,
            tuxedo_home_dir  => $tuxedo_location,
            tns_file_dir     => $tns_location,
            db2_sqllib_dir   => $db2_sqllib_location,
            cobol_home_dir   => $cobol_location,
          }
        }
        else {
          fail("tools_install_user entry is not specified in 'users' hash table in the YAML file")
        }
        # Elasticsearch install admin user
        $es_install_admin = $users_hiera['es_user']
        if ($es_install_admin) and ($es_install_admin != '') {
          $es_install_admin_user = $es_install_admin['name']
          $es_install_admin_user_home = $es_install_admin['home_dir']
          ::pt_setup::user_environment { "${es_install_admin_user}_environment":
            ensure           => $ensure,
            os_user          => $es_install_admin_user,
            os_user_home_dir => $es_install_admin_user_home,
            ps_home_dir      => $pshome_location,
            ps_cfg_home_dir  => $pscfg_location,
            ps_app_home_dir  => $psapphome_location,
            ps_cust_home_dir => $pscusthome_location,
            oracle_home_dir  => $oracle_location,
            tuxedo_home_dir  => $tuxedo_location,
            db2_sqllib_dir   => $db2_sqllib_location,
            tns_file_dir     => $tns_location,
            cobol_home_dir   => $cobol_location,
          }
        }
        else {
          fail("es_user entry is not specified in 'users' hash table in the YAML file")
        }
        # PeopleSoft application install user
        $psft_app_installer = $users_hiera['app_install_user']
        if ($psft_app_installer) and ($psft_app_installer != '') {
          $psft_app_install_user = $psft_app_installer['name']
          $psft_app_install_user_home = $psft_app_installer['home_dir']
          ::pt_setup::user_environment { "${psft_app_install_user}_environment":
            ensure           => $ensure,
            os_user          => $psft_app_install_user,
            os_user_home_dir => $psft_app_install_user_home,
            ps_home_dir      => $pshome_location,
            ps_app_home_dir  => $psapphome_location,
            ps_cust_home_dir => $pscusthome_location,
            oracle_home_dir  => $oracle_location,
            tuxedo_home_dir  => $tuxedo_location,
            db2_sqllib_dir   => $db2_sqllib_location,
            tns_file_dir     => $tns_location,
            cobol_home_dir   => $cobol_location,
          }
        }
        else {
          fail("app_install_user entry is not specified in 'users' hash table in the YAML file")
        }
      }
    }
  }
  if $::osfamily == 'windows' {
    ::pt_setup::user_environment { "psft_win_environment":
      ensure           => $ensure,
      ps_home_dir      => $pshome_location,
      ps_cfg_home_dir  => $pscfg_location,
      ps_app_home_dir  => $psapphome_location,
      ps_cust_home_dir => $pscusthome_location,
      tns_file_dir     => $tns_location,
    }
  }
}
