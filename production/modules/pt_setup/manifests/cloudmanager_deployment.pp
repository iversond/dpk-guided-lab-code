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
class pt_setup::cloudmanager_deployment(
  $ensure                 = present,
  $tools_install_user     = undef,
  $tools_install_group    = undef,
  $os_user                = undef,
  $ps_home_dir            = undef,
  $ps_app_home_dir        = undef,
  $ps_cfg_home_dir        = undef,
  $prcs_domain_name       = undef,
  $opc_user_name          = undef,
  $opc_domain_name        = undef,
  $ps_dpk_location        = undef,
) {
    notify { "Applying pt_setup::cloudmanager_deployment": }

    $cloud_manager_settings_tag = 'cloud_manager_settings'
    pt_deploy_cloudmanager { $cloud_manager_settings_tag:
      ensure                => $ensure,
      deploy_user           => $tools_install_user,
      deploy_user_group     => $tools_install_group,
      os_user               => $os_user,
      ps_home_dir           => $ps_home_dir,
      ps_app_home_dir       => $ps_app_home_dir,
      ps_cfg_home_dir       => $ps_cfg_home_dir,
      prcs_domain_name      => $prcs_domain_name,
      opc_user_name         => $opc_user_name,
      opc_domain_name       => $opc_domain_name,
      ps_dpk_location       => $ps_dpk_location,
    } 
    
    if $ensure == present {
      notify { 'cloudmanager_deployment_start':
         require => Pt_deploy_cloudmanager[$cloud_manager_settings_tag]
      }
    }
  }
