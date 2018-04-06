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
$webserver_props = [
  "webserver_home = /opt/oracle/psft/pt/bea",
  "webserver_admin_user = system",
  "webserver_admin_pwd = Welcome1"
]

$webprofile_props = [
  "profile_name = DEV",
  "profile_user = PTWEBSERVER",
  "profile_pwd = PTWEBSERVER"
]

pt_opa_domain { "OPA":
  ensure                => 'present',
  os_user               => 'psadm2',
  os_user_group         => 'oracle',
  ps_home_dir           => '/opt/oracle/psft/pt/tools',
  ps_app_home_dir       => '/opt/oracle/psft/ptdb/apptools',
  webapp_dir            => '/home/psadm2/psft/pt/8.54',
  webserver_properties  => $webserver_props,
  logoutput             => true,
  http_port             => '8844',
  opa_war_file          => '/opt/oracle/psft/pt/opa/determinations-server.war',
  loglevel              => debug,
}
