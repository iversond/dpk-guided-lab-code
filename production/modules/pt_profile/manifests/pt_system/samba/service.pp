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
class pt_profile::pt_system::samba::service (
  $service_emsure = $::pt_profile::pt_system::samba::params::service_ensure,
  $service_enable = $::pt_profile::pt_system::samba::params::service_enable,
  $service_name   = $::pt_profile::pt_system::samba::params::service_name,
  $config_file    = $::pt_profile::pt_system::samba::params::config_file,
) inherits ::pt_profile::pt_system::samba::params {

  service { 'samba':
    ensure     => $service_ensure,
    enable     => $service_enable,
    name       => $service_name,
    hasstatus  => true,
    hasrestart => true,
    subscribe  => File[$config_file],
  }
}

