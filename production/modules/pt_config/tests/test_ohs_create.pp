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
$webserver_settings = [
  "webserver_type           = ohs",
  "webserver_home           = /opt/oracle/psft/pt/bea/ohs",
  "webserver_admin_user     = system",
  "webserver_admin_user_pwd = Welcome123",
  "webserver_admin_port     = 7700",
  "webserver_http_port      = 7740",
  "webserver_https_port     = 7743",
]

pt_ohs_domain { "ohsdom":
  ensure              => 'present',
  os_user             => 'psadm2',
  domain_home_dir     => '/home/psadm2/psft/pt/8.55',
  webserver_settings  =>  $webserver_settings,
  pia_webserver_type  => 'weblogic',
  pia_webserver_host  => "${::fqdn}",
  pia_webserver_port  => 8000,
  domain_start        => true,
}
