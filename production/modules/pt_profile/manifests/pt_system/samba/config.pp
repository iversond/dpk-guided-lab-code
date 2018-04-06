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
class pt_profile::pt_system::samba::config (
  $ensure      = 'present',
  $config_file = $::pt_profile::pt_system::samba::params::config_file,
) inherits ::pt_profile::pt_system::samba::params {

  if $ensure == present {
    concat { $config_file:
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      backup  => true,
    }

    concat::fragment { 'global-settings':
      target  => $config_file,
      order   => '01',
      content => template('pt_profile/smb.conf.erb'),
    }

    # set 'nobody' user in samba database
    $pwd_cmd = $::pt_profile::pt_system::samba::params::pwd_cmd
    exec { 'nobdy_user':
      command => "${pwd_cmd} -na nobody",
      onlyif  => "/usr/bin/test -f ${pwd_cmd}"
    }
  }
  elsif $ensure == absent {
    file { $config_file:
      content => template('pt_profile/smb.conf.orig.erb')
    }
    # delete 'nobody' user in samba database
    exec { 'nobdy_user':
      command => "${pwd_cmd} -x nobody >/dev/null",
      onlyif  => [ "/usr/bin/test -f ${pwd_cmd}", "${pwd_cmd} -d nobody >/dev/null" ]
    }
  }
}
