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
# Define:
# This class updates the network information in /etc/hosts
# if the host gets a new IP address. This service applies to
# virtual box
#
class pt_setup::psft_netupdate_service (
  $ensure          = present,
  ) {
    if $::kernel == 'Linux' {
      $psft_netupdate_service = 'psft-netupdate'
      $service_file    = "/etc/init.d/${psft_netupdate_service}"

      $services_lock_dir = hiera('services_lock_dir', '/var/lock/subsys')
      $service_lock_file = "${services_lock_dir}/${psft_netupdate_service}"

      file { $psft_netupdate_service:
        ensure  => $ensure,
        path    => $service_file,
        content => template("pt_setup/${psft_netupdate_service}.erb"),
        mode    => '0755',
      }
      if $ensure == present {
        service { $psft_netupdate_service:
          ensure     => 'running',
          provider   => "redhat",
          enable     => true,
          hasstatus  => true,
          hasrestart => true,
          require    => File[$psft_netupdate_service],
        }
      }
      elsif $ensure == absent {
        exec { $psft_netupdate_service:
          command => "chkconfig ${psft_netupdate_service} --del",
          onlyif  => "test -e ${service_file}",
          path    => [ "/usr/bin:/sbin" ],
          require => File[$psft_netupdate_service],
        }
      }
      file { $service_lock_file:
        ensure   => $ensure,
        content  => '',
      }
    }
  }
