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
  "db_name = T55SS10R",
  "db_type = ORACLE",
  "db_opr_id = VP1",
  "db_opr_pwd = VP1",
  "db_connect_id = people",
  "db_connect_pwd = peop1e",
]

$site_name = 'ps'
$props = [
  "PTWebProfileConfig = [
  env.webprofilename=PROD,
  env.helpurl=http://www.oracle2.com/pls/topic/lookup?id=%CONTEXT_ID%&ctx=pt853pbr0,
  env.updateonlycustomproperty=N,
  env.propertyname=EnablePNSubscriptions,
  env.validationtype=1,
  env.longvalue=true
  ]",
]

#$props = strip_keyval_array($props2)
notice ("\n\nPlugin Properties: ${props}\n")

pt_acm_plugin { "webprofile":
  os_user           => 'psadm2',
  db_settings       => $db_settings,
  run_control_id    => 'webprofile',
  plugin_list =>  $props,
  ps_home_dir       => '/opt/oracle/psft/pt/pt/ps_home',
  logoutput         => true,
  loglevel          => debug,
    oracle_home_dir => '/opt/oracle/psft/pt/pt/oracle-client/12.1.0.2',
      tuxedo_home_dir => '/opt/oracle/psft/pt/pt/bea/tuxedo/tuxedo12.1.3.0.0',

}
