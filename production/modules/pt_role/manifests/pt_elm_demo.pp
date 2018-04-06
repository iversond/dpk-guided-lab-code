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
class pt_role::pt_elm_demo inherits pt_role::pt_app_base {

  notify { "Applying pt_role::pt_elm_demo": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')

  if $env_type != 'fulltier' {
    fail('The pt_elm_demo role can only be applied to env_type of fulltier')
  }
  if $ensure == present {
    contain ::pt_profile::pt_password
    Class['::pt_profile::pt_system'] ->
    Class['::pt_profile::pt_app_deployment'] ->
    Class['::pt_profile::pt_tools_deployment'] ->
    Class['::pt_profile::pt_oracleserver'] ->
    Class['::pt_profile::pt_psft_environment'] ->
    Class['::pt_profile::pt_psft_db'] ->
    Class['::pt_profile::pt_appserver'] ->
    Class['::pt_profile::pt_prcs'] ->
    Class['::pt_profile::pt_pia'] ->
    Class['::pt_profile::pt_samba'] ->
    Class['::pt_profile::pt_password'] ->
    Class['::pt_profile::pt_tools_preboot_config'] ->
    Class['::pt_profile::pt_domain_boot'] ->
    Class['::pt_profile::pt_tools_postboot_config'] ->
    Class['::pt_profile::pt_source_details']
  }
  elsif $ensure == absent {
    Class['::pt_profile::pt_source_details'] ->
    Class['::pt_profile::pt_samba'] ->
    Class['::pt_profile::pt_pia'] ->
    Class['::pt_profile::pt_prcs'] ->
    Class['::pt_profile::pt_appserver'] ->
    Class['::pt_profile::pt_psft_db'] ->
    Class['::pt_profile::pt_psft_environment'] ->
    Class['::pt_profile::pt_oracleserver'] ->
    Class['::pt_profile::pt_tools_deployment'] ->
    Class['::pt_profile::pt_app_deployment'] ->
    Class['::pt_profile::pt_system']
  }
  else {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
}
