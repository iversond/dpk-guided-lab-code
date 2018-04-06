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
class pt_profile::pt_system::samba::params {
  $service_enable        = true
  $service_ensure        = running

  $config_file           = '/etc/samba/smb.conf'
  $pwd_cmd               = '/usr/bin/smbpasswd'

  # globals
  $global_workgroup      = 'WORKGROUP'
  $global_netbios_name   = 'CDA'
  $global_security       = 'user'
  $global_user_file      = '/etc/samba/smbusers'
  $global_guest_map      = 'Bad User'
  $global_guest_account  = 'nobody'
  $global_guest_ok       = 'yes'
  $global_log_file       = '/var/log/samba.log.%m'
  $global_log_level      = 2
  $global_log_size       = 1000
  $global_socket_options = "TCP_NODELAY SO_RCVBUF=8192 SO_SNDBUF=8192"
  $global_printing       = 'bsd'

  case $::osfamily {
    'RedHat': {
      $service_name           = 'smb'
    }
    'Debian': {
      $service_name           = 'smbd'
    }
    default: {
      fail("${::osfamily} is not supported for samba")
    }
  }

}
