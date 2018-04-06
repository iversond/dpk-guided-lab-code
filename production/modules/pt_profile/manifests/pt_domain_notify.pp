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
class pt_profile::pt_domain_notify {
  notify { "Applying pt_profile::pt_domain_notify": }

  $ensure   = hiera('ensure')
  if !($ensure in [ 'present', 'absent']) {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('This profile can only be applied to env_type of fulltier or midtier')
  }

  if $::osfamily != 'windows' {
    $notify_file = '/tmp/notify'
  }
  else {
    $temp_dir_orig = $env_temp
    $temp_dir = regsubst("$temp_dir_orig", "\\\\", "/", "G")
    $notify_file = "$temp_dir/notify"
  }

  $notify_time = strftime("%Y-%m-%d:%r")
  $notify_content = "notify domains at ${notify_time}"

  file { $notify_file:
    ensure  => $ensure,
    content => $notify_content,
  }
}
