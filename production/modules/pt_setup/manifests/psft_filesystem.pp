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
class pt_setup::psft_filesystem {
  $ensure          = hiera('ensure', present)
  $db_location     = hiera('db_location')
  $pt_location     = hiera('pt_location')

  $ptc_location = "${pt_location}/tools_client"

  if $ensure == present {
    @file { $pt_location:
      ensure  => directory,
      mode   => '0755',
    }

    @file { $db_location:
      ensure  => directory,
      mode   => '0755',
    }

    @file { $ptc_location:
      ensure  => directory,
      recurse => true,
      mode   => '0755',
    }
  }
  elsif $ensure == absent {
    @file { $ptc_location:
      ensure  => absent,
      recurse => true,
      purge   => true,
      force   => true,
    }
  }
}
