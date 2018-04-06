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
# IMPORTANT NOTE:
# This class very simply adds a tnsnames entry for a DB service. If the
# service is already present it replaces it. If ensure is set to
# 'absent', the corresponding tns entry is removed from the file
#
define pt_setup::tns_admin (
  $ensure          = present,
  $db_name         = undef,
  $db_host         = undef,
  $db_port         = '1521',
  $db_protocol     = 'TCP',
  $db_service_name = undef,
  $tns_file_name   = undef,
  ) {

  $db_is_rac_hiera = hiera('db_is_rac', 'false')
  $db_is_rac = str2bool($db_is_rac_hiera)

  pt_tns_entry { $title:
    ensure          => $ensure,
    db_name         => $db_name,
    db_host         => $db_host,
    db_port         => $db_port,
    db_protocol     => $db_protocol,
    db_service_name => $db_service_name,
    db_is_rac       => $db_is_rac,
    tns_file_name   => $tns_file_name,
  }
}
