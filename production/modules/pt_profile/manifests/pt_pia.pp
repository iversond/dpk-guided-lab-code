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
class pt_profile::pt_pia {
  notify { "Applying pt_profile::pt_pia": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_pia profile can only be applied to env_type of fulltier or midtier')
  }

  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }

  $pshome_hiera       = hiera('ps_home')
  $pshome_location    = $pshome_hiera['location']

  $setup_services     = hiera('setup_services')
  if $setup_services == true {
    if ($::kernel == 'Linux') or ($::kernel == 'DISABLEAIX') {
      $pia_service      = 'psft-pia'
      $pia_service_file = "/etc/init.d/${pia_service}"

      $services_lock_dir = hiera('services_lock_dir', '/var/lock/subsys')
      file { $pia_service:
        ensure  => $ensure,
        path    => $pia_service_file,
        content => template("pt_profile/${pia_service}.erb"),
        mode    => '0755',
      }
    }
  }
  $recreate = hiera('recreate', false)

  # setup database connectivity
  $db_platform = hiera('db_platform')
  $db_platform_upper = upcase($db_platform)

  if $db_platform_upper == 'ORACLE' {
    $tns_admin_list = hiera('tns_admin_list')
    $tns_admin_list.each |$db_name, $db_info| {
      include ::pt_profile::pt_tns_admin
      realize ( ::Pt_setup::Tns_admin[$db_name] )
    }
  }
  elsif ($db_platform_upper == 'DB2ODBC') or ($db_platform_upper == 'DB2UNIX') {
    $db2_server_list = hiera('db2_server_list')
    $db2_server_list.each |$db_name, $db_info| {
      include ::pt_profile::pt_db2_setup
      realize ( ::Pt_setup::Db2_connectivity[$db_name] )
    }
  }
  else {
    $mssql_server_list = hiera('mssql_server_list')
    $mssql_server_list.each |$db_name, $db_info| {
      include ::pt_profile::pt_mssql_setup
      realize ( ::Pt_setup::Mssql_connectivity[$db_name] )
    }
  }

  $pia_domain_list = hiera('pia_domain_list')
  $pia_domain_list.each |$domain_name, $pia_domain_info| {
    notify {"Setting up PIA domain ${domain_name}":}

    $os_user            = $pia_domain_info['os_user']
    $ps_cfg_home_dir    = $pia_domain_info['ps_cfg_home_dir']
    notify {"PIA domain ${domain_name} PS Configuration home: ${ps_cfg_home_dir}":}

    $webserver_settings = $pia_domain_info['webserver_settings']
    validate_hash($webserver_settings)
    $webserver_settings_array  = join_keys_to_values($webserver_settings, '=')
    notify {"PIA domain ${domain_name} the provided WebServer settings\n":}

    $config_settings = $pia_domain_info['config_settings']
    if $config_settings {
      validate_hash($config_settings)
      $config_settings_array = hash_of_hash_to_array_of_array($config_settings)
      notify {"PIA domain ${domain_name} is provided with the settings\n":}
    }
    $gateway_user          = $pia_domain_info['gateway_user']
    $gateway_user_pwd      = $pia_domain_info['gateway_user_pwd']
    $auth_token_domain     = $pia_domain_info['auth_token_domain']

    $pia_site_list         = $pia_domain_info['site_list']

    $pia_site_list_array   = hash_of_hash_to_array_of_array($pia_site_list)

    pt_webserver_domain { $domain_name:
      ensure                => $ensure,
      ps_home_dir           => $pshome_location,
      os_user               => $os_user,
      ps_cfg_home_dir       => $ps_cfg_home_dir,
      webserver_settings    => $webserver_settings_array,
      config_settings       => $config_settings_array,
      gateway_user          => $gateway_user,
      gateway_user_pwd      => $gateway_user_pwd,
      auth_token_domain     => $auth_token_domain,
      site_list             => $pia_site_list_array,
      recreate              => $recreate,
    }
    if $setup_services == true {
      if ($::kernel == 'Linux') or ($::kernel == 'DISABLEAIX') {

        ::pt_setup::pia_domain_service { $domain_name:
          ensure          => $ensure,
          domain_name     => $domain_name,
          os_user         => $os_user,
          ps_home_dir     => $pshome_location,
          ps_cfg_home_dir => $ps_cfg_home_dir,
          require         => File[$pia_service],
        }
      }
    }
  }
  if $setup_services == true {
    if $::kernel == 'Linux' {
      if $ensure == present {
        service { $pia_service:
          ensure     => 'running',
          provider   => "redhat",
          enable     => true,
          hasstatus  => true,
          hasrestart => true,
          require    => File[$pia_service],
        }
      }
      elsif $ensure == absent {
        exec { $pia_service:
          command => "chkconfig ${pia_service} --del",
          onlyif  => "test -e ${pia_service_file}",
          path    => [ "/usr/bin:/sbin" ],
          require => File[$pia_service],
        }
      }
      $service_lock_file = "${services_lock_dir}/${pia_service}"
      file { $service_lock_file:
        ensure   => $ensure,
        content  => '',
      }
    }
    if $::kernel == 'DISABLEAIX' {
      if $ensure == present {
        service { $pia_service:
          ensure     => 'running',
          provider   => "AIX",
          enable     => true,
          hasstatus  => true,
          hasrestart => true,
          require    => File[$pia_service],
        }
      }
      elsif $ensure == absent {
        exec { $pia_service:
          command => "lssrc -s ${pia_service}",
          onlyif  => "test -e ${pia_service_file}",
          path    => [ "/usr/bin:/sbin" ],
          require => File[$pia_service],
        }
      }
      $service_lock_file = "${services_lock_dir}/${pia_service}"
      file { $service_lock_file:
        ensure   => $ensure,
        content  => '',
      }
    }
  }
}
