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
# Define:
#
#
define pt_setup::source_details (
  $ensure          = present,
  $tools_version   = undef,
  $db_boot_user    = undef,
  $db_connect_user = undef,
  $pi_home_dir     = undef,
  $pia_url         = undef,
  $source_file_dir = undef,
  ) {
    include ::pt_setup::psft_filesystem
    realize ( ::File[$source_file_dir] )

    if $ensure == present {
      $source_file = "${source_file_dir}/source.properties"

      file { $source_file:
        ensure  => $ensure,
        path    => "${source_file}",
        content => template("pt_setup/source_details.erb"),
        mode    => '0755',
      }
    }
  }
