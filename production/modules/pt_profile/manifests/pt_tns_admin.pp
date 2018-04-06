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
class pt_profile::pt_tns_admin {
  notify { "Applying pt_profile::pt_tns_admin": }

  $ensure = hiera('ensure')
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier', 'dbtier' ]) {
    fail('env_type parameter value must be fulltier, midtier or dbtier')
  }
  $pt_location = hiera('pt_location')
  $windows_tns_dir = "${pt_location}/tools_client"

  $db_location = hiera('db_location')

  include ::pt_setup::psft_filesystem
  if $ensure == present {
    realize ( ::File[$pt_location] )
    realize ( ::File[$db_location] )
  }
  realize ( ::File[$windows_tns_dir] )

  $tns_windows_file = "${windows_tns_dir}/tnsnames.ora"

  $tns_dir       = hiera('tns_dir')
  $tns_file_name = "${tns_dir}/tnsnames.ora"
  notify { "TNS names is set to ${tns_file_name}": }

  $tns_admin_list = hiera('tns_admin_list')
  $tns_admin_list.each |$db_name, $tns_entry| {
    notify {"Setting up TNS entry for database ${db_name}":}

    # this resource will be made virtual to account for
    # the same resource being used by appserver and process
    # scheduler. It will be realized in both appserver and process
    # scheduler profiles

    @::pt_setup::tns_admin { $db_name:
      ensure          => $ensure,
      db_name         => $db_name,
      db_host         => $tns_entry['db_host'],
      db_port         => $tns_entry['db_port'],
      db_protocol     => $tns_entry['db_protocol'],
      db_service_name => $tns_entry['db_service_name'],
      tns_file_name   => $tns_file_name,
    }

    if $::osfamily == 'windows' {
      $db_ipaddress = $tns_entry['db_host']
    }
    else {
      if $tns_entry['db_host'] != $::fqdn {
        $db_ipaddress = $tns_entry['db_host']
      }
      else {
      $db_ipaddress = ipaddress($tns_entry['db_host'])
      }
    }
    if $ensure == present {
      @::pt_setup::tns_admin { "${db_name}_win":
        ensure          => $ensure,
        db_name         => $db_name,
        db_host         => $db_ipaddress,
        db_port         => $tns_entry['db_port'],
        db_protocol     => $tns_entry['db_protocol'],
        db_service_name => $tns_entry['db_service_name'],
        tns_file_name   => $tns_windows_file,
        require         => File[$windows_tns_dir],
      }
    }
  }
}
