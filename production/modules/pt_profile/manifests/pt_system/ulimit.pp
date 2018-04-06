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
# == Class: pt_ulimit
#
# === Parameters:
#
# $ensure:: Default: present
#
define pt_profile::pt_system::ulimit (
  $ensure          = present,
  $domain_name     = undef,
  $ulimit_settings = undef,
  ) {
    notify {"\nUpdating ulimits for ${domain_name}":}

    if $::kernel == 'Linux' {
      $ulimit_settings.each |$ulimit_key, $ulimit_value| {
        $ulimit_type = split_string($ulimit_key, '.')[0]
        $ulimit_item = split_string($ulimit_key, '.')[1]

        pt_ulimit_entry {"${domain_name}.${ulimit_key}":
          ensure        => $ensure,
          ulimit_domain => $domain_name,
          ulimit_type   => $ulimit_type,
          ulimit_item   => $ulimit_item,
          ulimit_value  => $ulimit_value,
        }
      }
    }
}
