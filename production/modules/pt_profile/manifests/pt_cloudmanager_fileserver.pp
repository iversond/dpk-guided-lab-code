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
class pt_profile::pt_cloudmanager_fileserver {
  notify { "Applying pt_profile::pt_cloudmanager_fileserver": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_cloudmanager_fileserver profile can only be applied to env_type of fulltier or midtier')
  }
  $fileserver_creation       = hiera('fileserver_creation')
  if ( $fileserver_creation == false){
    notify { "Cloud Manager Fileserver configuration disabled": }
  }
  else{
    notify { "Cloud Manager Fileserver configuration enabled": }
    $cloudmanager_fileserver_tag = 'cloudmanager_fileserver_config'

    $fileserver_settings = hiera('fileserver_sync_settings')
    validate_hash($fileserver_settings)
    $fileserver_settings_array  = join_keys_to_values($fileserver_settings, '=')
    $fileserver_mount_path = hiera('fileserver_mount_path')
    $fileserver_hostname   = hiera('fileserver_hostname')
    $fileserver_dpk_path   = hiera('fileserver_dpk_path')
    $psapphome_hiera = hiera('ps_app_home', '')
    if ($psapphome_hiera) and ($psapphome_hiera != '') {
      $psapphome_location = $psapphome_hiera['location']
    }

    pt_cm_fileserver_config { $cloudmanager_fileserver_tag:
      ensure                => $ensure,
      fileserver_mount_path => $fileserver_mount_path,
      fileserver_hostname   => $fileserver_hostname,
      fileserver_dpk_path   => $fileserver_dpk_path,
      fileserver_settings   => $fileserver_settings_array,
      ps_app_home_dir       => $psapphome_location,
    }
  }
}

