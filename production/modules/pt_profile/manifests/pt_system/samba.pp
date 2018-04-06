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
class pt_profile::pt_system::samba (
  $ensure                = present,
  $config_file           = $pt_profile::pt_system::samba::params::config,
  $global_workgroup      = $pt_profile::pt_system::samba::params::global_workgroup,
  $global_netbios_name   = $pt_profile::pt_system::samba::params::global_netbios_name,
  $global_security       = $pt_profile::pt_system::samba::params::global_security,
  $global_user_file      = $pt_profile::pt_system::samba::params::global_user_file,
  $global_guest_map      = $pt_profile::pt_system::samba::params::global_guest_map,
  $global_guest_account  = $pt_profile::pt_system::samba::params::global_guest_account,
  $global_guest_ok       = $pt_profile::pt_system::samba::params::global_guest_ok,
  $global_log_file       = $pt_profile::pt_system::samba::params::global_log_file,
  $global_log_level      = $pt_profile::pt_system::samba::params::global_log_level,
  $global_log_size       = $pt_profile::pt_system::samba::params::global_log_size,
  $global_socket_options = $pt_profile::pt_system::samba::params::global_socket_options,
  $global_printing       = $pt_profile::pt_system::samba::params::global_socket_printing,
  $service_name          = $pt_profile::pt_system::samba::params::service_name,
  $service_ensure        = $pt_profile::pt_system::samba::params::service_ensure,
  $service_enable        = $pt_profile::pt_system::samba::params::service_enable,
) inherits pt_profile::pt_system::samba::params {

  class { '::pt_profile::pt_system::samba::config': 
    ensure => $ensure,
  }
  class { '::pt_profile::pt_system::samba::service': }

  Class['::pt_profile::pt_system::samba::config'] ->
  Class['::pt_profile::pt_system::samba::service']
}
