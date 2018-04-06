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
#
# This class sets up the groups required by the PeopleSoft
# runtime system
#
class pt_profile::pt_system::groups (
  $ensure     = 'present',
  $group_list = undef,
) {
  if $group_list {
    $group_list.each |$group_info| {
      $group_name   = $group_info['name']
      $group_id     = $group_info['gid']
      $group_remove = $group_info['remove']

      if $ensure == present {
        group { $group_name:
          ensure => $ensure,
          gid    => $group_id,
        }
      }
      elsif $ensure == absent {
        if $group_remove == false {
          notify {"Group ${group_name} will not be removed":}
        }
        else {
          group { $group_name:
            ensure => $ensure,
            gid    => $group_id,
          }
          # remove the group using exec resource instead, looks like
          # a bug in Puppet user & group resource type. When forcelocal=true
          # flag is set, assumption is luserdel & lgroupdel should be used
          # instead of userdel & groupdel
          #exec { "lgroupdel ${group_name}":
          #  path    => [ "/bin", "/usr/bin", "/usr/sbin/" ],
          #  onlyif  => "cat /etc/group | grep ${group_name} >/dev/null"
          #}
        }
      }
      notify {"Ensure ${ensure} group ${group_name} with id ${group_id}":}
    }
  }
}
