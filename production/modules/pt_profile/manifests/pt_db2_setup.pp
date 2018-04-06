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
class pt_profile::pt_db2_setup {
  notify { "Applying pt_profile::pt_db2_setup": }

  $ensure = hiera('ensure')
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type = hiera('env_type')
  if $env_type != 'midtier' {
    fail('The pt_db2_setup profile can only be applied to midtier env_type')
  }

  $pshome_hiera         = hiera('ps_home')
  $pshome_location      = $pshome_hiera['location']

  $db2_hiera         = hiera('db2_client')
  $db2_sqllib_dir    = $db2_hiera['sqllib_location']
  if $db2_sqllib_dir == undef {
    fail("sqllib_location entry is not specified in 'db2_client' hash table in the YAML file")
  }
  if $::osfamily != 'windows' {
    $db2_instance_user = $db2_hiera['instance_user']
    if $db2_instance_user == undef {
      fail("db2_insance_user is not specified in 'db2_client' hash table in the YAML file for non Windows platform")
    }
  }
  $db2_server_list = hiera('db2_server_list')
  $db2_server_list.each |$db_name, $db2_server_entry| {
    notify {"Setting up connectivity for DB2 database ${db_name}":}

    # this resource will be made virtual to account for
    # the same resource being used by appserver and process
    # scheduler. It will be realized in both appserver and process
    # scheduler profiles
    if $ensure == present {
      if defined(File[$pshome_location]) {
        notice("PS_HOME File resource already defined")
      }
      else {
        notice("PS_HOME File resource not defined")
        file { "$pshome_location":
          ensure => directory,
        }
      }
      @::pt_setup::db2_connectivity { $db_name:
        ensure            => $ensure,
        ps_home           => $pshome_location,
        db_name           => $db_name,
        db2_type          => $db2_server_entry['db2_type'],
        db2_host          => $db2_server_entry['db2_host'],
        db2_port          => $db2_server_entry['db2_port'],
        db2_node          => $db2_server_entry['db2_node'],
        db2_target_db     => $db2_server_entry['db2_target_db'],
        db2_user_name     => $db2_server_entry['db2_user_name'],
        db2_user_pwd      => $db2_server_entry['db2_user_pwd'],
        db2_sqllib_dir    => $db2_sqllib_dir,
        db2_instance_user => $db2_instance_user,
        require           => File[$pshome_location],
      }
    }
    else {
      @::pt_setup::db2_connectivity { $db_name:
        ensure            => $ensure,
        ps_home           => $pshome_location,
        db_name           => $db_name,
        db2_type          => $db2_server_entry['db2_type'],
        db2_host          => $db2_server_entry['db2_host'],
        db2_port          => $db2_server_entry['db2_port'],
        db2_node          => $db2_server_entry['db2_node'],
        db2_target_db     => $db2_server_entry['db2_target_db'],
        db2_user_name     => $db2_server_entry['db2_user_name'],
        db2_user_pwd      => $db2_server_entry['db2_user_pwd'],
        db2_sqllib_dir    => $db2_sqllib_dir,
        db2_instance_user => $db2_instance_user,
      }
    }
  }
}
