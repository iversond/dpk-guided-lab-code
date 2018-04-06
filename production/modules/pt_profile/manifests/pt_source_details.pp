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
class pt_profile::pt_source_details {
  notify { "Applying pt_profile::pt_source_details": }

  $ensure   = hiera('ensure', present)
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier' ]) {
    fail('pt_source_details profile is applicable to env_type of fulltier or midtier')
  }
  
  $source_details = true
  
  if $source_details == true {
    $tools_version = hiera('tools_version')
    notice ("Tools version [$tools_version]")

    $db_user       = hiera('db_user')
    notice ("DB user [$db_user]")

    $connect_user  = hiera('db_connect_id')
    notice ("Connect user [$pi_home]")

    $pi_home       = hiera('pi_home_location', "")
    notice ("PI_HOME location [$pi_home]")

    $pia_host     = hiera('pia_host_name', $::fqdn)
    notice ("PIA host [$pia_host]")

    if $::osfamily == 'windows' {
      $pia_host_value = $pia_host
    }
    else {
      if $pia_host == $::fqdn {
        $pia_host_value = $::ipaddress
      }
      else {
        $pia_host_value = $pia_host
      }
    }
    $pia_port = hiera('pia_http_port')
    notice ("PIA port [$pia_port]")

    $pia_url = "http://${pia_host_value}:${pia_port}/ps/signon.html"
    notice ("PIA URL [$pia_url]")

    $pt_location = hiera('pt_location')
    $source_file_dir = "${pt_location}/tools_client"
    notice ("Source properties file location [$source_file_dir]")

    ::pt_setup::source_details { "psft_source_details":
      ensure          => $ensure,
      tools_version   => $tools_version,
      db_boot_user    => $db_user,
      db_connect_user => $connect_user,
      pi_home_dir     => $pi_home,
      pia_url         => $pia_url,
      source_file_dir => $source_file_dir,
    }
  }
}
