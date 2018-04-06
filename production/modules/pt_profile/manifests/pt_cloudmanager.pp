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
 *  Copyright (C) 1988, 2015, Oracle and/or its affiliates.
 *  All Rights Reserved.
 * ***************************************************************
 */
class pt_profile::pt_cloudmanager {
  notify { "Applying pt_profile::pt_cloudmanager": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_cloudmanager profile can only be applied to env_type of fulltier or midtier')
  }
  $prcs_domain_name   = hiera('prcs_domain_name')
  $cloud_home         = hiera('cloud_home')

  $cloud_manager_config_tag = 'cloud_manager_config'
  $cloud_manager_settings_tag = 'cloud_manager_settings'
  $cloud_manager_settings = hiera("${cloud_manager_settings_tag}")

  $os_user            = $cloud_manager_settings['os_user']
  $ps_cfg_home_dir    = $cloud_manager_settings['ps_cfg_home_dir']
  $opc_user_name      = $cloud_manager_settings['opc_user_name']
  $opc_domain_name    = $cloud_manager_settings['opc_domain_name']

  pt_cloudmanager_config { $cloud_manager_config_tag:
    ensure                => $ensure,
    os_user               => $os_user,
    ps_cfg_home_dir       => $ps_cfg_home_dir,
    prcs_domain_name      => $prcs_domain_name,
    opc_user_name         => $opc_user_name,
    opc_domain_name       => $opc_domain_name,
    cloud_home            => $cloud_home,
  }
}

