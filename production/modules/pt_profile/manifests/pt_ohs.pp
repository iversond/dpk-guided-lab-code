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
class pt_profile::pt_ohs {
  notify { "Applying pt_profile::pt_ohs": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_ohs profile can only be applied to env_type of fulltier or midtier')
  }
  $setup_ohs = hiera('setup_ohs', false)
  if $setup_ohs == false {
    fail('The pt_ohs profile can only be applied if setup_ohs Hiera data is true')
  }

  $ohs_domain_info = hiera('ohs_domain')
  $domain_name = $ohs_domain_info['name']
  notify {"Setting up OHS domain ${domain_name}":}

  $os_user         = $ohs_domain_info['os_user']
  $domain_home_dir = $ohs_domain_info['domain_home_dir']

  $webserver_settings  = $ohs_domain_info['webserver_settings']
  validate_hash($webserver_settings)
  $webserver_settings_array  = join_keys_to_values($webserver_settings, '=')
  notify {"OHS domain ${domain_name} is loaded with theWebServer settings \n":}

  $pia_webserver_type = $ohs_domain_info['pia_webserver_type']
  $pia_webserver_host = $ohs_domain_info['pia_webserver_host']
  $pia_webserver_port = $ohs_domain_info['pia_webserver_port']
  $node_manager_port  = $ohs_domain_info['node_manager_port']

  pt_ohs_domain { $domain_name:
    ensure             => $ensure,
    os_user            => $os_user,
    domain_home_dir    => $domain_home_dir,
    webserver_settings => $webserver_settings_array,
    pia_webserver_type => $pia_webserver_type,
    pia_webserver_host => $pia_webserver_host,
    pia_webserver_port => $pia_webserver_port,
    node_manager_port  => $node_manager_port,
  }
  $setup_services     = hiera('setup_services')
  if $setup_services == true {
    $listen_port = $webserver_settings['webserver_http_port']
    notify {"OHS domain listen port: ${listen_port}\n":}

    ::pt_setup::psft_ohs_service { $domain_name:
      ensure          => $ensure,
      domain_name     => $domain_name,
      os_user         => $os_user,
      domain_home_dir => $domain_home_dir,
      listen_port     => $listen_port,
    }
  }
  if $ensure == present {
    if $setup_services == true {
      Pt_ohs_domain[$domain_name] ->
      ::Pt_setup::Psft_ohs_service[$domain_name]
    }
  }
  elsif $ensure == absent {
    if $setup_services == true {
      ::Pt_setup::Psft_ohs_service[$domain_name] ->
      Pt_ohs_domain[$domain_name]
    }
  }
  else {
      fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
}
