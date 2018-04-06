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
class pt_profile::pt_psft_db {

  # Hiera lookups
  $ensure                   = hiera('ensure')
  $env_type                 = hiera('env_type')
  if !($env_type in [ 'fulltier', 'dbtier']) {
    fail('The pt_psft_db profile can only be applied to env_type of fulltier or dbtier')
  }
  $tools_archive_location   = hiera('archive_location')

  if $::osfamily != 'windows' {
    $users_hiera            = hiera('users')
    $psft_user                 = $users_hiera['psft_user']
    if ($psft_user) and ($psft_user != '') {
      $psft_install_user_name  = $psft_user['name']
      $psft_install_group_name = $psft_user['gid']

      $oracle_install_user       = $users_hiera['oracle_user']
      if ($oracle_install_user) and ($oracle_install_user != '') {
        $oracle_install_user_name  = $oracle_install_user['name']
        $oracle_install_group_name = $oracle_install_user['gid']
      }
      else {
        $oracle_install_user_name  = $psft_install_user_name
        $oracle_install_group_name = $psft_install_group_name
      }
    }
    else {
      $oracle_install_user    = $users_hiera['oracle_user']
      if $oracle_install_user == undef {
        fail("oracle_user entry is not specified in 'users' hash table in the YAML file")
      }
      $oracle_install_user_name   = $oracle_install_user['name']
      $oracle_install_group_name = $oracle_install_user['gid']
    }
  }
  $db_name = hiera('db_name')

  $db_type_hiera = hiera('db_type')
  $db_type    = downcase($db_type_hiera)
  notice ("PeopleSoft database type ${db_type}")

  $psftdb_hiera    = hiera('psft_db')
  $psftdb_location = $psftdb_hiera['location']
  $psftdb_type     = $psftdb_hiera['type']
  $psftdb_type_tag = "${psftdb_type}-db-${db_type}"
  $psftdb_cdb_tag  = "CDBDMO"

  $psftdb_archive_file   = get_matched_file($tools_archive_location,
                                            $psftdb_type_tag)
  if $psftdb_archive_file == '' {
    fail("Unable to locate archive (tgz) file for PeopleSoft database in ${tools_archive_location}")
  }
  else {
    notice ("Found PeopleSoft database archive file ${psftdb_archive_file}")
  }

  $oracle_hiera          = hiera('oracle_server')
  $oracle_location       = $oracle_hiera['location']

  $db_connect_id         = hiera('db_connect_id')
  $db_connect_pwd        = hiera('db_connect_pwd')
  $db_admin_pwd          = hiera('db_admin_pwd')
  $db_access_pwd         = hiera('access_pwd')

  $container_name_hiera  = $psftdb_hiera['container_name']
  if $container_name_hiera == undef or $container_name_hiera == '' {
    # generate the container name
    $cdb_tag = 'CDB'
    $psftdb_type_upper = upcase($psftdb_type)
    $container_temp    = "${cdb_tag}${psftdb_type_upper}"
    $container_name    = inline_template("<%= @container_temp[0..7] %>")
    notice ("Generated container name: ${container_name}")
  }
  else {
    $container_name    = $container_name_hiera
    notice ("User passed in container name: ${container_name}")
  }
  $new_container_hiera  = $psftdb_hiera['new_container']
  if $new_container_hiera == undef or $new_container_hiera == '' {
    $new_container = true
  }
  else {
    $new_container = str2bool($new_container_hiera)
  }
  notice ("Is it a new container database ${new_container}")

  if $new_container == true {
    $cold_backup_container_hiera  = $psftdb_hiera['cold_backup_container']
    if $cold_backup_container_hiera == undef or $cold_backup_container_hiera == '' {
      $cold_backup_container = true
    }
    else {
      $cold_backup_container = str2bool($cold_backup_container_hiera)
    }
  }
  else {
    $cold_backup_container = true
  }
  notice ("Is it a cold-backup container database ${cold_backup_container}")

  if ($new_container == true) {
    if $cold_backup_container == false {
      notice ("Container database uses dbca")
      $container_settings = $psftdb_hiera['container_settings']
      if $container_settings {
        validate_hash($container_settings)
        $container_settings_array = join_keys_to_values($container_settings, '=')
        notify {"PeopleSoft database container settings: ${container_settings_array}\n":}
      }
    }
    else {
      notice ("Container database uses cold-backup")
      $psftdb_cdb_file = get_matched_file($tools_archive_location, $psftdb_cdb_tag)
      if $psftdb_cdb_file == '' {
        fail("Unable to locate zip file for container cold-backup in ${tools_archive_location}")
      }
      else {
        notice ("Found cold-back container zip file ${psftdb_cdb_file}")
      }
    }
  }
  $rac_database_hiera  = $psftdb_hiera['rac_database']
  if str2bool($rac_database_hiera) == true {
    $rac_database = true
    $container_instance_name  = $psftdb_hiera['container_instance_name']
    if $container_instance_name == undef or $container_instance_name == '' {
      fail("Container instance name is empty. Required for RAC databases")
    }
  }
  else {
    $rac_database = false
    $container_instance_name = $container_name
  }

  $redeploy = hiera('redeploy', false)
  $recreate = hiera('recreate', false)

  pt_deploy_psftdb { $db_name:
    ensure            => $ensure,
    deploy_user       => $oracle_install_user_name,
    deploy_user_group => $oracle_install_group_name,
    archive_file      => $psftdb_archive_file,
    deploy_location   => $psftdb_location,
    redeploy          => $redeploy,
  }

  include ::pt_profile::pt_tns_admin
  realize ( ::Pt_setup::Tns_admin[$db_name] )
  if $ensure == present {
    realize ( ::Pt_setup::Tns_admin["${db_name}_win"] )
  }
  pt_setup_psftdb { $db_name:
    ensure                => $ensure,
    oracle_user           => $oracle_install_user_name,
    oracle_user_group     => $oracle_install_group_name,
    container_name        => $container_name,
    new_container         => $new_container,
    rac_database            => $rac_database,
    container_instance_name => $container_instance_name,
    cold_backup_container => $cold_backup_container,
    container_settings    => $container_settings_array,
    container_backup_file => $psftdb_cdb_file,
    database_dir          => $psftdb_location,
    oracle_home_dir       => $oracle_location,
    db_connect_id         => $db_connect_id,
    db_connect_pwd        => $db_connect_pwd,
    db_access_pwd         => $db_access_pwd,
    db_admin_pwd          => $db_admin_pwd,
    recreate              => $recreate,
    require               => ::Pt_setup::Tns_admin[$db_name],
  }
  $setup_services     = hiera('setup_services')
  if $setup_services == true {
    ::pt_setup::psft_db_service { $db_name:
      ensure          => $ensure,
      db_name         => $db_name,
      oracle_user     => $oracle_install_user_name,
      container_name  => $container_name,
      database_dir    => $psftdb_location,
      oracle_home_dir => $oracle_location,
    }
  }
  if $ensure == present {
    if $setup_services == true {
      Pt_deploy_psftdb[$db_name] ->
      Pt_setup_psftdb[$db_name] ->
      ::Pt_setup::Psft_db_service[$db_name]
    }
    else {
      Pt_deploy_psftdb[$db_name] ->
      Pt_setup_psftdb[$db_name]
    }
  }
  elsif $ensure == absent {
    if $setup_services == true {
      ::Pt_setup::Psft_db_service[$db_name] ->
      Pt_setup_psftdb[$db_name] ->
      Pt_deploy_psftdb[$db_name]
    }
    else {
      Pt_setup_psftdb[$db_name] ->
      Pt_deploy_psftdb[$db_name]
    }
  }
  else {
      fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
}
