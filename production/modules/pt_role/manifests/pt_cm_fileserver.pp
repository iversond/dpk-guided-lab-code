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
class pt_role::pt_cm_fileserver {

  notify { "Applying pt_role::pt_cm_fileserver": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')

  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_cm_fileserver profile can only be applied to env_type of fulltier or midtier')
  }
  
  contain ::pt_profile::pt_cloudmanager_fileserver
  
  if $ensure == present {
    contain ::pt_profile::pt_cm_postboot_config
    Class['::pt_profile::pt_cm_postboot_config'] ->
    Class['::pt_profile::pt_cloudmanager_fileserver']
  }
  elsif $ensure == absent {
    Class['::pt_profile::pt_cloudmanager_fileserver']
  }
}
