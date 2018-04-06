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
$db_settings = [
  "db_name = T55110SS",
  "db_type = ORACLE",
  "db_opr_id = VP1",
  "db_opr_pwd = VP1",
  "db_connect_id = people",
  "db_connect_pwd = peop1e",
]

$feature_settings = [
  "QUICKSRV = No",
  "PPM = No",
  "WSL = No",
  "DOMAIN_GW = No",
  "QUERYSRV = No",
  "JSL = Yes",
  "PUBSUB = No",
  "RENSRV = No",
  "ANALYTICSRV = No",
  "MCF = No",
  "DBGSRV = No",
  "JRAD = No",
]

$config_settings = [
  "JOLT Listener/Port = 9033",
   "Workstation Listener/Port = 7033",
   "Security/DomainConnectionPwd = PeopleS0ft",
   "PSAPPSRV/Min Instances = 2",
   "PSAPPSRV/Max Instances = 2",
]

$sqbracketed_cfg_arr  = regsubst($config_settings, '^(.*)/(.*)$', '[\1]/\2')
notice ("\n\nConfig  Properties: ${sqbracketed_cfg_arr}\n")

$props = strip_keyval_array($feature_settings)
$ubx_arr  = regsubst($props, '^(.*)=(.*)$', '{\1}=\2')
notice ("\n\nFeature  Properties: ${ubx_arr}\n")

# add a notify to the file resource
file { "/tmp/restart":
  owner   => "root",
  group   => "root",
  content => "I am ready",
}

pt_appserver_domain { "APPDOM":
  ensure           => 'present',
  os_user          => 'psadm2',
  ps_home_dir      => '/opt/oracle/psft/pt/pt/ps_home',
  db_settings      => $db_settings,
  feature_settings => $feature_settings,
  config_settings  => $config_settings,
  oracle_home_dir  => '/opt/oracle/psft/pt/pt/oracle-client/12.1.0.2',
  tuxedo_home_dir  => '/opt/oracle/psft/pt/pt/bea/tuxedo/tuxedo12.1.3.0.0',
}

pt_appserver_domain_boot { "APPDOM":
  ensure           => 'running',
  os_user          => 'psadm2',
  ps_home_dir      => '/opt/oracle/psft/pt/pt/ps_home',
  oracle_home_dir  => '/opt/oracle/psft/pt/pt/oracle-client/12.1.0.2',
  tuxedo_home_dir  => '/opt/oracle/psft/pt/pt/bea/tuxedo/tuxedo12.1.3.0.0',
  require          => Pt_appserver_domain["APPDOM"],
  subscribe        => File['/tmp/restart'],
}
