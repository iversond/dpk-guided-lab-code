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
class pt_profile::pt_samba {
  if $::osfamily != 'windows' {
    $ensure = hiera('ensure')
    if !($ensure in [ 'present', 'absent']) {
      fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
    }
    $env_type = hiera('env_type')
    if !($env_type in [ 'fulltier', 'midtier' ]) {
      fail('pt_samba profile is applicable to env_type of fulltier or midtier')
    }

    notify { "Applying pt_profile::pt_samba: ${ensure}": }

    $setup_samba = hiera('setup_samba')
    if $setup_samba == true {
      class { '::pt_profile::pt_system::samba':
        ensure => $ensure,
      }
      contain ::pt_profile::pt_system::samba

      $pi_home_hiera  = hiera('pi_home', '')
      if ($pi_home_hiera) and ($pi_home_hiera != '') {
        $pi_home_location  = $pi_home_hiera['location']
        notice ("Setting up Samba share fo PI Home location is  ${pi_home_location}")
        ::pt_profile::pt_system::samba::share { 'pi_home_share':
          share_name      => 'pi_home',
          ensure          => $ensure,
          share_comment   => "Samba share for PI Home directory",
          share_path      => $pi_home_location,
          share_writeable => 'no',
          share_available => 'yes',
        }
      }
      $pt_location = hiera('pt_location')
      $windows_tns_dir = "${pt_location}/tools_client"

      notice ("Setting up Samba share fo Windows TNS location is  ${windows_tns_dir}")
      ::pt_profile::pt_system::samba::share { 'tns_win_share':
        share_name      => 'tools_client',
        ensure          => $ensure,
        share_comment   => "Samba share for Tools Client directory",
        share_path      => $windows_tns_dir,
        share_writeable => 'no',
        share_available => 'yes',
      }
    }
  }
}
