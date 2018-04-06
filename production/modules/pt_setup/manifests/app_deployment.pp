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
class pt_setup::app_deployment (
  $ensure               = present,
  $deploy_apphome_only  = false,
  $app_archive_location = undef,
  $app_install_user     = undef,
  $app_install_group    = undef,
  $db_type              = undef,
  $ps_apphome_location  = undef,
  $ps_apphome_remove    = true,
  $pi_home_location     = undef,
  $pi_home_remove       = true,
  $ps_custhome_location = undef,
  $ps_custhome_remove   = true,
  $redeploy             = false,
) {
    notice ("Applying pt_setup::app_deployment")

    $ps_apphome_tag   = 'psapphome'
    $pi_home_tag      = 'pihome'
    $ps_custhome_tag      = 'pscusthome'

    if $ensure == present {
      $pt_location = hiera('pt_location')
      notice ("APP Deployment PT location is  ${pt_location}")

      include ::pt_setup::psft_filesystem
      realize ( ::File[$pt_location] )

      # retrieve the archives for each App component
    $ps_apphome_archive_file = get_matched_file($app_archive_location, $ps_apphome_tag)
      if $ps_apphome_archive_file == '' {
        fail("Unable to locate archive (tgz) file for PS_APP_HOME in ${app_archive_location}")
      }
    }
    $ps_apphome_hiera = hiera('ps_app_home')
  $ps_apphome_extract_only_hiera = $ps_apphome_hiera['extract_only']
  $apphome_extract_only = str2bool($ps_apphome_extract_only_hiera)

    notice ("PS Application Home extract only flag: ${apphome_extract_only}")
    $apphome_patches = hiera('apphome_patches', '')
    if ($apphome_patches) and ($apphome_patches != '') {
      notice ("App Home patches exists")
      $apphome_patches_list = values($apphome_patches)
    }
    else {
      notice ("App Home patches do not exist")
      $apphome_patches_list = undef
    }
    $install_type     = hiera('install_type')	
    if ($install_type == 'FRESH') {
      $include_ml_files = $ps_apphome_hiera['include_ml_files']
      if ($include_ml_files == true) {
        $translations_zip_file = get_matched_file($app_archive_location, 'translations')
        if $translations_zip_file == '' {
          fail("Unable to locate Application Translations zip file for PS_APP_HOME in ${app_archive_location}")
        }
      }
    }

    # deploy each app component
    pt_deploy_apphome { $ps_apphome_tag:
      ensure            => $ensure,
      deploy_user       => $app_install_user,
      deploy_user_group => $app_install_group,
      db_type           => $db_type,
      archive_file      => $ps_apphome_archive_file,
      deploy_location   => $ps_apphome_location,
      redeploy          => $redeploy,
      remove            => $ps_apphome_remove,
      extract_only      => $apphome_extract_only,
      install_type      => $install_type,
      patch_list        => $apphome_patches_list,
      translations_zip_file => $translations_zip_file,
    }

    if $deploy_apphome_only == false {
      if ($pi_home_location) {
        if $ensure == present {
        $pi_home_archive_file = get_matched_file($app_archive_location, $pi_home_tag)
        }
        if $pi_home_archive_file != '' {
          pt_deploy_pihome { $pi_home_tag:
            ensure            => $ensure,
            deploy_user       => $app_install_user,
            deploy_user_group => $app_install_group,
            archive_file      => $pi_home_archive_file,
            deploy_location   => $pi_home_location,
            redeploy          => $redeploy,
            remove            => $pi_home_remove,
          }
          Pt_deploy_apphome[$ps_apphome_tag] ->
          Pt_deploy_pihome[$pi_home_tag]
        }
      }
      if ($ps_custhome_location) {
        notice ("PS Customer Home extract only flag: ${custhome_extract_only}")

        if $ensure == present {
        $ps_custhome_archive_file = get_matched_file($app_archive_location, $ps_custhome_tag)
        }
        if $ps_custhome_archive_file != '' {
          pt_deploy_archive { $ps_custhome_tag:
            ensure            => $ensure,
            deploy_user       => $app_install_user,
            deploy_user_group => $app_install_group,
            archive_file      => $ps_custhome_archive_file,
            deploy_location   => $ps_custhome_location,
            redeploy          => $redeploy,
            remove            => $ps_custhome_remove,
          }
        }
      }
    }
}
