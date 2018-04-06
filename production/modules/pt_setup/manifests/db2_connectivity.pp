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
# This class very simply sets up DB2 server connectivity
#
define pt_setup::db2_connectivity (
  $ensure            = present,
  $ps_home           = undef,
  $db_name           = undef,
  $db2_type          = undef,
  $db2_host          = undef,
  $db2_port          = undef,
  $db2_node          = undef,
  $db2_target_db     = undef,
  $db2_user_name     = undef,
  $db2_user_pwd      = undef,
  $db2_sqllib_dir    = undef,
  $db2_instance_user = undef,
  ) {
  pt_db2_connectivity { $title:
    ensure            => $ensure,
    ps_home_dir       => $ps_home,
    db_name           => $db_name,
    db2_type          => $db2_type,
    db2_host          => $db2_host,
    db2_port          => $db2_port,
    db2_node          => $db2_node,
    db2_target_db     => $db2_target_db,
    db2_user_name     => $db2_user_name,
    db2_user_pwd      => $db2_user_pwd,
    db2_sqllib_dir    => $db2_sqllib_dir,
    db2_instance_user => $db2_instance_user,
  }
}
