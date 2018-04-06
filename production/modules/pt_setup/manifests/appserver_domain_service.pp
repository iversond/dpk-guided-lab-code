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
# This class sets up the appserver domain service for the platform
#
define pt_setup::appserver_domain_service (
  $ensure          = present,
  $domain_name     = undef,
  $os_user         = undef,
  $ps_home_dir     = undef,
  $ps_cfg_home_dir = undef,
  ) {
    $domain_name_lower = downcase($domain_name)

    if $::kernel == 'Linux' {
      $appserver_service = 'psft-appserver'
      $service_file      = "/etc/init.d/${appserver_service}"

      $domain_script_file = "${ps_cfg_home_dir}/appserv/${domain_name}/${appserver_service}-domain-${domain_name_lower}.sh"

      file { "appsrv_${ps_cfg_home_dir}_${domain_name_lower}":
        ensure  => $ensure,
        path    => $domain_script_file,
        content => template("pt_setup/${appserver_service}-domain.erb"),
        mode    => '0755',
      }
      if $ensure == present {
        file_line { "appsrv_domain_${domain_name_lower}_start":
          path   => $service_file,
          match  => 'start_ret=0',
          line   => "   start_ret=0\n\n   sh ${domain_script_file} start\n   domain_ret=$?\n   start_ret=$(( start_ret | domain_ret ))\n",
        }

        file_line { "appsrv_domain_${domain_name_lower}_stop":
          path   => $service_file,
          match  => 'stop_ret=0',
          line   => "   stop_ret=0\n\n   sh ${domain_script_file} stop\n   domain_ret=$?\n   stop_ret=$(( stop_ret | domain_ret ))\n",
        }

        file_line { "appsrv_domain_${domain_name_lower}_status":
          path   => $service_file,
          match  => 'status_ret=0',
          line   => "   status_ret=0\n\n   sh ${domain_script_file} status\n",
        }
      }
    }
  }
