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
# == Defninition: samba share definied type
#
# == Requires: Concat module
#
# Parameters:
#  $share_name
#  The name of the share being accessed
#  $share_comment
#  string to associate with the new share
#  $share_path
#  Points to the directory containing the user defined share definitions
#  $share_writeable
#  $share_available
#
# Sample Usage:
#
# pt_profile::pt_system::samba::share { 'test_share':
#   share_comment   => 'This is a test Samba share',
#   share_name      => 'share_one',
#   share_path      => '/opt/psft',
#   share_writeable => 'no',
#   share_available => 'yes',
# }
#
#
define pt_profile::pt_system::samba::share (
  $share_name,
  $ensure          = 'present',
  $share_comment   = undef,
  $share_path      = undef,
  $share_writeable = undef,
  $share_available = undef,
) {
  include '::pt_profile::pt_system::samba::params'

  if $ensure == present {
    validate_string($share_name)

    if $share_comment {
      validate_string($share_comment)
    }
    if $share_path {
      validate_absolute_path($share_path)
    }
    if $share_writeable {
      validate_string($share_writeable)
    }
    if $share_available {
      validate_string($share_available)
    }
    concat::fragment { "share-${name}":
      target  => $::pt_profile::pt_system::samba::params::config_file,
      order   => '20',
      content => template('pt_profile/shares.erb'),
    }
  }
}
