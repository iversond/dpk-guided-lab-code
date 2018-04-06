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
  "webserver_type            = weblogic",
  "webserver_home            = /opt/oracle/psft/pt/bea",
  "webserver_admin_user      = system",
  "webserver_admin_user_pwd  = Welcome123",
  "webserver_admin_port      = 8000",
  "webserver_http_port       = 8000",
  "webserver_https_port      = 8443",
]

$webprofile_settings = [
  "profile_name     = PROD",
  "profile_user     = PTWEBSERVER",
  "profile_user_pwd = Passw0rd",
]

$config_settings = [
    "Servers/PIA/WebServer/PIA/WebServerLog/PIA = [\"LoggingEnabled=true\"]",
    "Servers/PIA                                = [\"CustomIdentityKeyStorePassPhrase=Passw0rd\",
                                                   \"CustomTrustKeyStorePassPhrase=Passw0rd\",
                                                   \"WeblogicPluginEnabled=true\",
                                                   \"KeyStores=CustomIdentityAndCustomTrust\"]",
    "Servers/PIA/SSL/PIA                        = [\"ServerPrivateKeyPassPhrase=Passw0rd\"]",
]


pt_webserver_domain { "peoplesoft":
  ensure              => 'present',
  os_user             => 'psadm2',
  ps_home_dir         => '/opt/oracle/psft/pt/ps_home8.55.805R1',
  ps_cfg_home_dir     => '/home/psadm2/psft/pt/8.55',
  webserver_settings  =>  $webserver_settings,
  webprofile_settings =>  $webprofile_settings,
  config_settings     =>  $config_settings,
  gateway_user_pwd    => 'password',
}
