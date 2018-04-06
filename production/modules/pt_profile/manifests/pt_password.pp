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
class pt_profile::pt_password {

  $env_type = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_password profile can only be applied to env_type of fulltier or midtier')
  }
  $change_password = hiera('change_password', false)
  if $change_password == true {
    $db_admin_pwd     = hiera('db_admin_pwd')
    $db_access_pwd    = hiera('access_pwd')
    $db_access_id     = hiera('access_id')
    $db_connect_pwd   = hiera('db_connect_pwd')
    $db_connect_id    = hiera('db_connect_id')
    $db_user_pwd      = hiera('db_user_pwd')
    $db_user          = hiera('db_user')
    $db_name          = hiera('db_name')
    $domain_user      = hiera('domain_user')
    $db_type          = hiera('db_platform')
    $pshome_hiera     = hiera('ps_home')
    $pshome_location  = $pshome_hiera['location']
    if ($env_type in ['fulltier']) {
      $oracle_hiera = hiera('oracle_server')
    }
    else
    {
      $oracle_hiera = hiera('oracle_client')
    }
    $oracle_client_home = $oracle_hiera['location']

    $pia_domain_list   = hiera('pia_domain_list', [{'site_list' => 'none'}])
    $pia_domain_number = 0
    $pia_domain_list.each |$domain_name, $pia_domain_info| {
      $pia_site_list         = $pia_domain_info['site_list']
      if $pia_site_list != "none" {
        $pia_site_list_array   = hash_of_hash_to_array_of_array($pia_site_list)
        $pia_domain_number     = $pia_domain_number + 1
      }
      else
      {
        $pia_site_list_array   = 'none'
      }
      pt_password{ $domain_name:
        db_access_id          => $db_access_id,
        db_access_pwd         => $db_access_pwd,
        db_admin_pwd          => $db_admin_pwd,
        db_connect_id         => $db_connect_id,
        db_connect_pwd        => $db_connect_pwd,
        db_opr_id             => $db_user,
        db_opr_pwd            => $db_user_pwd,
        db_name               => $db_name,
        db_type               => $db_type,
        db_server_name        => $db_name,
        os_user               => $domain_user,
        ps_home               => $pshome_location,
        change_password       => $change_password,
        pia_site_list         => $pia_site_list_array,
        oracle_client_home    => $oracle_client_home,
        pia_domain_number     => $pia_domain_number,
        domain_name           => $domain_name
      }
    }
  }
}
