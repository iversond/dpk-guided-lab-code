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
file { "/opt/oracle/psft/db":
  ensure => 'directory',
  mode   => '0755',
}

pt_deploy_oracleclient { "oracleclient":
  ensure                    => present,
  deploy_user               => 'oracle',
  deploy_user_group         => 'oinstall',
  archive_file              => '/opt/oracle/psft/dpk/archives/pt-oracleclient12.1.0.2.tgz',
  deploy_location           => '/opt/oracle/psft/pt/oracle-client/12.1.0.2',
  oracle_inventory_location => '/opt/oracle/psft/db/oraInventory',
  oracle_inventory_user     => 'oracle',
  oracle_inventory_group    => 'oinstall',
}
