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
class pt_profile::pt_cloudmanager_patch {
  notify { "Applying pt_profile::pt_cloudmanager_patch": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_cloudmanager_patch profile can only be applied to env_type of fulltier or midtier')
  }
  $patch_cloud_manager       = hiera('patch_cloud_manager')
  if ( $patch_cloud_manager == false){
    notify { "Cloud Manager Patching disabled": }
  }
  else{
    notify { "Cloud Manager Patching enabled": }
    $cloud_manager_patch_settings = hiera('cloud_manager_patch_settings')
    $cloud_manager_patch_settings.each |$patch_item, $patch_info| {
      notify {"Cloud Manager Patching item  ${patch_item}":}
      notify {"Cloud Manager Patching Info  ${patch_info}":}

      $patch_type            = $patch_info['patch_type']
      $patch_mode             = $patch_info['patch_mode']
      $patch_source            = $patch_info['patch_source']
      $patch_target            = $patch_info['patch_target']
      $os_user                = $patch_info['os_user']

      pt_cloud_manager_patch {"${patch_item}_patch_target":
        ensure    => $ensure,
        patch_type => $patch_type,
        patch_target      => $patch_target,
        patch_source    => $patch_source,
        patch_mode      => $patch_mode,
        os_user   => $os_user,
      }
    }
  }
}

