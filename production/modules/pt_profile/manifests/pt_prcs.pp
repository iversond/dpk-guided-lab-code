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
class pt_profile::pt_prcs {
  notify { "Applying pt_profile::pt_prcs": }

  $ensure = hiera('ensure')
  $env_type = hiera('env_type')

  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_prcs profile can only be applied to env_type of fulltier or midtier')
  }

  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $pshome_hiera         = hiera('ps_home')
  $pshome_location      = $pshome_hiera['location']
  $pshome_db_type       = $pshome_hiera['db_type']
  $pshome_db_type_upper = upcase($pshome_db_type)

  $psapphome_hiera    = hiera('ps_app_home', '')
  if ($psapphome_hiera) and ($psapphome_hiera != '') {
    $psapphome_location = $psapphome_hiera['location']
  }

  $setup_services     = hiera('setup_services')
  if $setup_services == true {
    if ($::kernel == 'Linux') or ($::kernel == 'DISABLEAIX') {
      $prcs_service      = 'psft-prcs'
      $prcs_service_file = "/etc/init.d/${prcs_service}"

      $services_lock_dir = hiera('services_lock_dir', '/var/lock/subsys')
      file { $prcs_service:
        ensure  => $ensure,
        path    => $prcs_service_file,
        content => template("pt_profile/${prcs_service}.erb"),
        mode    => '0755',
      }
    }
  }
  $recreate = hiera('recreate', false)

  $prcs_domain_list = hiera('prcs_domain_list')
  $prcs_domain_list.each |$domain_name, $prcs_domain_info| {
    notify {"Setting up Process Scheduler domain ${domain_name}":}

    $db_settings        = $prcs_domain_info['db_settings']
    validate_hash($db_settings)
    $db_settings_array  = join_keys_to_values($db_settings, '=')
    notify {"PRCS domain ${domain_name} with the DB settings\n":}

    $config_settings    = $prcs_domain_info['config_settings']
    validate_hash($config_settings)
    $config_settings_array = join_keys_to_values($config_settings, '=')
    notify {"PRCS domain ${domain_name} with Config settings\n":}

    $feature_settings   = $prcs_domain_info['feature_settings']
    validate_hash($feature_settings)
    $feature_settings_array = join_keys_to_values($feature_settings, '=')
    notify {"PRCS domain ${domain_name} Feature settings: ${feature_settings_array}\n":}

    $env_settings   = $prcs_domain_info['env_settings']
    if $env_settings {
      validate_hash($env_settings)
      $env_settings_array = join_keys_to_values($env_settings, '=')
      notify {"PRCS domain ${domain_name} Env settings: ${env_settings_array}\n":}
    }
    # get the database platform
    $prcs_db_name      = $db_settings['db_name']
    $db_platform       = $db_settings['db_type']
    $db_platform_upper = upcase($db_platform)

    # make sure the DB platform matches the PS_HOME db_type
    if $db_platform_upper != $pshome_db_type_upper {
      fail("Process Scheduler domain ${domain_name} database type ${$db_platform_upper} \
           do not match PS_HOME type $pshome_db_type_upper}")
                                           }
    if $db_platform_upper == 'ORACLE' {
      if $env_type == 'midtier' {
        $oracle_hiera = hiera('oracle_client')
      }
      elsif $env_type == 'fulltier' {
        $oracle_hiera = hiera('oracle_server')
      }
      else {
        fail("Process Scheduler domain cannot be configured for dbtier env_type")
      }
      $db_location = $oracle_hiera['location']
    }
    elsif ($db_platform_upper == 'DB2ODBC') or ($db_platform_upper == 'DB2UNIX') {
      if $env_type == 'midtier' {
        $db2_hiera   = hiera('db2_client')
        $db_location = $db2_hiera['sqllib_location']
      }
      else {
        fail("Application Server domain cannot be configured for ${env_type} \
             env_type when the database platform is #{db_platform_upper}")
      }
    }
    elsif ($db_platform_upper == 'MSSQL') {
      if $::osfamily != 'windows' {
        fail("${db_platform_upper} database type is not supported for midtier setup on $::osfamily")
      }
    }
    else {
      fail("Process Scheduler domain setup for DB platform ${db_platform_upper} is not supported")
    }
    $os_user          = $prcs_domain_info['os_user']
    $ps_cfg_home_dir  = $prcs_domain_info['ps_cfg_home_dir']
    notify {"PRCS domain ${domain_name} PS Configuration home: ${ps_cfg_home_dir}":}

    if $db_platform == 'ORACLE' {
      include ::pt_profile::pt_tns_admin
      realize ( ::Pt_setup::Tns_admin[$prcs_db_name] )

      $prcs_require = [ ::Pt_setup::Tns_admin[$prcs_db_name] ]

      if $ensure == present {
          realize ( ::Pt_setup::Tns_admin["${prcs_db_name}_win"] )
        }
      }
    elsif ($db_platform_upper == 'DB2ODBC') or ($db_platform_upper == 'DB2UNIX') {
      include ::pt_profile::pt_db2_setup
      realize ( ::Pt_setup::Db2_connectivity[$prcs_db_name] )

      $prcs_require = [ ::Pt_setup::DB2_connectivity[$prcs_db_name] ]
    }
    else {
      include ::pt_profile::pt_mssql_setup
      realize ( ::Pt_setup::Mssql_connectivity[$prcs_db_name] )

      $prcs_require = [ ::Pt_setup::Mssql_connectivity[$prcs_db_name] ]
    }
    pt_prcs_domain { $domain_name:
      ensure           => $ensure,
      ps_home_dir      => $pshome_location,
      os_user          => $os_user,
      ps_app_home_dir  => $psapphome_location,
      ps_cfg_home_dir  => $ps_cfg_home_dir,
      ps_cust_home_dir => $prcs_domain_info['ps_cust_home_dir'],
      db_settings      => $db_settings_array,
      config_settings  => $config_settings_array,
      feature_settings => $feature_settings_array,
      env_settings     => $env_settings_array,
      db_home_dir      => $db_location,
      recreate         => $recreate,
      require          => $prcs_require,
    }
    if $setup_services == true {
      if ($::kernel == 'Linux') or ($::kernel == 'DISABLEAIX') {

        ::pt_setup::prcs_domain_service { $domain_name:
          ensure          => $ensure,
          domain_name     => $domain_name,
          os_user         => $os_user,
          ps_home_dir     => $pshome_location,
          ps_cfg_home_dir => $ps_cfg_home_dir,
          require         => File[$prcs_service],
        }
      }
    }
  }
  if $setup_services == true {
    if $::kernel == 'Linux' {

      if $ensure == present {
        service { $prcs_service:
          ensure     => 'running',
          provider   => "redhat",
          enable     => true,
          hasstatus  => true,
          hasrestart => true,
          require    => File[$prcs_service],
        }
      }
      elsif $ensure == absent {
        exec { $prcs_service:
          command => "chkconfig ${prcs_service} --del",
          onlyif  => "test -e ${prcs_service_file}",
          path    => [ "/usr/bin:/sbin" ],
          require => File[$prcs_service],
        }
      }
      $service_lock_file = "${services_lock_dir}${prcs_service}"
      file { $service_lock_file:
        ensure   => $ensure,
        content  => '',
      }
    }
    if $::kernel == 'DISABLEAIX' {

      if $ensure == present {
        service { $prcs_service:
          ensure     => 'running',
          provider   => "AIX",
          enable     => true,
          hasstatus  => true,
          hasrestart => true,
          require    => File[$prcs_service],
        }
      }
      elsif $ensure == absent {
        exec { $prcs_service:
          command => "lssrc -s ${prcs_service} ",
          onlyif  => "test -e ${prcs_service_file}",
          path    => [ "/usr/bin:/sbin" ],
          require => File[$prcs_service],
        }
      }
      $service_lock_file = "${services_lock_dir}${prcs_service}"
      file { $service_lock_file:
        ensure   => $ensure,
        content  => '',
      }
    }
  }
}
