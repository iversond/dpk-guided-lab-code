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
class pt_profile::pt_mssql_setup {
  notify { "Applying pt_profile::pt_mssql_setup": }

  $ensure = hiera('ensure')
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type = hiera('env_type')
  if $env_type != 'midtier' {
    fail('The pt_mssql_setup profile can only be applied to midtier env_type')
  }
  if $::osfamily != 'windows' {
    fail('The pt_mssql_setup profile can only be applied on windows platforms')
  }
  $mssql_server_list = hiera('mssql_server_list')
  $mssql_server_list.each |$db_name, $mss_server_entry| {
    notify {"Setting up connectivity for MSSQL database ${db_name}":}

    # this resource will be made virtual to account for the same resource
    # being used by appserver and process scheduler. It will be realized
    # in both appserver and process scheduler profiles
    @::pt_setup::mssql_connectivity { $db_name:
      ensure      => $ensure,
      db_name     => $db_name,
      server_name => $mss_server_entry['mss_server_name'],
      odbc_name   => $mss_server_entry['mss_odbc_name'],
    }
  }
}
