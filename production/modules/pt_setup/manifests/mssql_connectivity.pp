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
#
# IMPORTANT NOTE:
# This class very simply sets up MSSQL server connectivity
#
define pt_setup::mssql_connectivity (
  $ensure      = present,
  $db_name     = undef,
  $server_name = undef,
  $odbc_name   = undef,
  ) {
  if $::osfamily == 'windows' {
    if $ensure == present {
      # set the ODBC for the database
      exec { "{db_name}_odbc_setup":
        command => "$system32\\odbcconf.exe /A {CONFIGSYSDSN \"${odbc_name}\" \"DSN=${db_name}|Server=${server_name}|Trusted_Connection=No|Database=${db_name}\"}",
      }
    }
    elsif $ensure == absent {
      $odbc_ds_reg_key   = "HKLM\\SOFTWARE\\ODBC\\ODBC.INI\\ODBC Data Sources"
      # remove the ODBC Datasources key
      exec { "${db_name}_odbc_ds":
        command => "$env_comspec /c REG DELETE \"${odbc_ds_reg_key}\" /v ${db_name} /f",
        onlyif  => "$env_comspec /c REG QUERY \"${odbc_ds_reg_key}\" /v ${db_name}",
      }

      $odbc_reg_key   = "HKLM\\SOFTWARE\\ODBC\\ODBC.INI\\"
      # remove the ODBC entry
      exec { "${db_name}_odbc":
        command => "$env_comspec /c REG DELETE \"${odbc_reg_key}${db_name}\" /f",
        onlyif  => "$env_comspec /c REG QUERY \"${odbc_reg_key}${db_name}\"",
      }
    }
  }
}
