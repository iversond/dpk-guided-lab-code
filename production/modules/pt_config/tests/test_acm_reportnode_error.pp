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
$props = [
  "env.distnodename = PRCS271",
  "env.opsys = 4",
  "env.uri_port=9900",
  "env.operpswd=beaweb",
  "env.uri_host=junk.tunk.com",
  "env.desclong_0=Node Setup",
  "env.uri_resource=SchedulerTransfer/tunk",
  "env.uri_host = aloha.punk.com",
  "env.wrkoperpswd=beaweb",
  "env.url = http://aloha.punk.com:8900/psreports/tunk",
  "env.cdm_proto=0",
]

#$props = strip_keyval_array($plugin_properties)
#notice ("\n\nPlugin Properties: ${props}\n")

pt_acm_plugin { "reportnode":
  os_user           => 'psadm2',
  run_control_id    => 'junk',
  plugin_name       => 'PTProcessSchedulerReportNode',
  plugin_properties =>  $props,
  ps_home_dir       => '/opt/oracle/psft/pt/tools',
  psconfig_set      => 'yes',
  logoutput         => true,
  loglevel          => debug,
}
