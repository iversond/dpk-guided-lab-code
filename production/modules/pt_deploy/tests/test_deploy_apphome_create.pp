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
user { "psadm1":
  ensure => present,
  gid    => 'oracle',
  managehome => true,
  home => '/home/psadm1',
}
pt_deploy_apphome { "ps_app_home":
  ensure            => present,
  deploy_user       => 'psadm1',
  deploy_user_group => 'oracle',
  archive_file      => '/opt/oracle/psft/dpk/archives/hr-psapphome92-8.55.805R1.tgz',
  deploy_location   => '/opt/oracle/psft/pt/ps_app_home',
  require           => User['psadm1'],
}
