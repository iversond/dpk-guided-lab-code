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
class pt_profile::pt_domain_boot {
  notify { "Applying pt_profile::pt_domain_boot": }

  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_domain_boot profile can only be applied to env_type of fulltier or midtier')
  }

  $ensure = hiera('ensure')
  if $ensure == present {
    $domain_action = 'running'
  }
  elsif $ensure == absent {
    $domain_action = 'stopped'
  }
  $pshome_hiera       = hiera('ps_home')
  $pshome_location    = $pshome_hiera['location']
  notify {"Domain boot PS Home [${pshome_location}]\n":}

  $domain_type = hiera('domain_type', "all")
  notify {"Domain Type [${domain_type}]\n":}

  $psapphome_hiera    = hiera('ps_app_home', '')
  if ($psapphome_hiera) and ($psapphome_hiera != '') {
    $psapphome_location = $psapphome_hiera['location']
    notify {"Domain boot PS APP Home: [${psapphome_location}]\n":}
  }
  if ($::osfamily == 'windows') and ($env_type == 'fulltier') {
    $oracleserver_hiera    = hiera('oracle_server')
    $oracle_listener_name = $oracleserver_hiera['listener_name']
    $oracle_listener_service = "OracleOraDB12cHomeTNSListener${oracle_listener_name}"
 
    $psftdb_hiera         = hiera('psft_db')
    $container_name_hiera = $psftdb_hiera['container_name']
    if $container_name_hiera == undef {
      # generate the container name
      $cdb_tag = 'CDB'
      $psftdb_type       = $psftdb_hiera['type']
      $psftdb_type_upper = upcase($psftdb_type)
      $container_temp    = "${cdb_tag}${psftdb_type_upper}"
      $container_name    = inline_template("<%= @container_temp[0..7] %>")
    }
    else {
      $container_name    = $container_name_hiera
    }
    $oracle_cdb_service  = "OracleService${container_name}"
  }
  if ($domain_type in [ 'all', 'appserver', 'appbatch']) {
    $appserver_domain_list = hiera('appserver_domain_list')
    $appserver_domain_list.each |$app_domain_name, $appserver_domain_info| {
      notify {"Setting up AppServer domain boot ${app_domain_name}":}

      $os_user          = $appserver_domain_info['os_user']
      $ps_cfg_home_dir  = $appserver_domain_info['ps_cfg_home_dir']

      pt_appserver_domain_boot { $app_domain_name:
        ensure           => $domain_action,
        ps_home_dir      => $pshome_location,
        ps_cfg_home_dir  => $ps_cfg_home_dir,
        os_user          => $os_user,
      }
      if ($::osfamily == 'windows') and ($env_type == 'fulltier') {
        $appserver_domain_service = "PsftAppServerDomain${app_domain_name}Service"

        $sc_path =  "$system32\\sc.exe"  
        exec { $appserver_domain_service:
          command => "$sc_path CONFIG \"${appserver_domain_service}\" depend= ${oracle_listener_service}/${oracle_cdb_service}",
          onlyif  => "$sc_path QUERY \"${appserver_domain_service}\"",
          require => Pt_appserver_domain_boot[$app_domain_name],
        }
      }
    }
  }
  if ($domain_type in [ 'all', 'prcs', 'appbatch']) {
    $prcs_domain_list = hiera('prcs_domain_list')
    $prcs_domain_list.each |$prcs_domain_name, $prcs_domain_info| {
      notify {"Setting up Process Scheduler domain boot ${prcs_domain_name}":}

      $os_user          = $prcs_domain_info['os_user']
      $ps_cfg_home_dir  = $prcs_domain_info['ps_cfg_home_dir']

      pt_prcs_domain_boot { $prcs_domain_name:
        ensure           => $domain_action,
        ps_home_dir      => $pshome_location,
        ps_cfg_home_dir  => $ps_cfg_home_dir,
        os_user          => $os_user,
      }
      if ($::osfamily == 'windows') and ($env_type == 'fulltier') {
        $prcs_domain_service = "PsftPrcsDomain${prcs_domain_name}Service"

        $sc_path =  "$system32\\sc.exe"  
        exec { $prcs_domain_service:
          command => "$sc_path CONFIG \"${prcs_domain_service}\" depend= ${oracle_listener_service}/${oracle_cdb_service}",
          onlyif  => "$sc_path QUERY \"${prcs_domain_service}\"",
          require => Pt_prcs_domain_boot[$prcs_domain_name],
        }
      }
    }
  }
  if ($domain_type in [ 'all', 'pia']) {
    $pia_domain_list = hiera('pia_domain_list')
    $pia_domain_list.each |$pia_domain_name, $pia_domain_info| {
      notify {"Setting up PIA domain boot ${pia_domain_name}":}

      $os_user            = $pia_domain_info['os_user']
      $ps_cfg_home_dir    = $pia_domain_info['ps_cfg_home_dir']

      $webserver_settings = $pia_domain_info['webserver_settings']
      validate_hash($webserver_settings)
      $webserver_settings_array  = join_keys_to_values($webserver_settings, '=')

      pt_webserver_domain_boot { $pia_domain_name:
        ensure             => $domain_action,
        ps_cfg_home_dir    => $ps_cfg_home_dir,
        os_user            => $os_user,
        webserver_settings => $webserver_settings_array,
      }
    }
  }
  $setup_ohs = hiera('setup_ohs')
  if $setup_ohs == true {
    $ohs_domain_info = hiera('ohs_domain')
    $domain_name = $ohs_domain_info['name']
    notify {"Setting up OHS domain boot ${domain_name}":}

    $os_user         = $ohs_domain_info['os_user']
    $domain_home_dir = $ohs_domain_info['domain_home_dir']

    $webserver_settings  = $ohs_domain_info['webserver_settings']
    validate_hash($webserver_settings)
    $webserver_settings_array  = join_keys_to_values($webserver_settings, '=')

    $node_manager_port  = $ohs_domain_info['node_manager_port']

    pt_ohs_domain_boot { $domain_name:
      ensure             => $domain_action,
      os_user            => $os_user,
      domain_home_dir    => $domain_home_dir,
      webserver_settings => $webserver_settings_array,
      node_manager_port  => $node_manager_port,
    }
  }
}
