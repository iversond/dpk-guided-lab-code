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
class pt_setup::tools_deployment (
  $ensure                 = present,
  $deploy_pshome_only     = false,
  $tools_archive_location = undef,
  $tools_install_user     = undef,
  $tools_install_group    = undef,
  $oracle_install_user    = undef,
  $oracle_install_group   = undef,
  $db_type                = undef,
  $pshome_location        = undef,
  $pshome_remove          = true,
  $inventory_location     = undef,
  $oracleclient_location  = undef,
  $oracleclient_remove    = true,
  $jdk_location           = undef,
  $jdk_remove             = true,
  $weblogic_location      = undef,
  $weblogic_remove        = true,
  $tuxedo_location        = undef,
  $tuxedo_remove          = true,
  $ohs_location           = undef,
  $ohs_remove             = true,
  $redeploy               = false,
) {
    notice ("Applying pt_setup::tools_deployment")

    $pshome_tag       = 'pshome'
    $jdk_tag          = 'jdk'
    $weblogic_tag     = 'weblogic'
    $tuxedo_tag       = 'tuxedo'
    $oracleclient_tag = 'oracleclient'
    $ohs_tag          = 'ohs'
    $cobol_tag        = 'cobol'

    if $ensure == present {
      $pt_location = hiera('pt_location')
      notice ("Tools deployment PT location is  ${pt_location}")

      $db_location = hiera('db_location')
      notice ("Tools deployment DB location is  ${db_location}")

      include ::pt_setup::psft_filesystem
      realize ( ::File[$pt_location] )
      realize ( ::File[$db_location] )

      # retrieve the archives for each Tools component
      $pshome_archive_file   = get_matched_file($tools_archive_location,
                                              $pshome_tag)
      if $pshome_archive_file == '' {
        fail("Unable to locate archive (tgz) file for PS_HOME in ${tools_archive_location}")
      }
    }
    if $deploy_pshome_only == false {
      if $ensure == present {
        if ($::kernel != 'AIX') {
        $jdk_archive_file      = get_matched_file($tools_archive_location,
                                                $jdk_tag)
        if $jdk_archive_file == '' {
          fail("Unable to locate archive (tgz) file for JDK in ${tools_archive_location}")
        }
        }
		
        $weblogic_archive_file = get_matched_file($tools_archive_location,
                                                $weblogic_tag)
        if $weblogic_archive_file == '' {
          fail("Unable to locate archive (tgz) file for Weblogic in ${tools_archive_location}")
        }
        $tuxedo_archive_file   = get_matched_file($tools_archive_location,
                                                $tuxedo_tag)
        if $tuxedo_archive_file == '' {
          fail("Unable to locate archive (tgz) file for Tuxedo in ${tools_archive_location}")
        }
      }
      $db_platform = hiera('db_platform')
      if ($oracleclient_location) and ($db_platform == 'ORACLE') {
        $deploy_oracleclient = true

        if $ensure == present {
          $oracleclient_archive_file = get_matched_file($tools_archive_location,
                                                      $oracleclient_tag)
          if $oracleclient_archive_file == '' {
            fail("Unable to locate archive (tgz) file for Oracle Client in ${tools_archive_location}")
          }
        }
        $oracleclient_patches = hiera('oracle_client_patches', '')
        if ($oracleclient_patches) and ($oracleclient_patches != '') {
          notice ("Oracle Client patches exists")
          $oracleclient_patches_list = values($oracleclient_patches)
        }
        else {
          notice ("Oracle Client patches do not exists")
          $oracleclient_patches_list = undef
        }
        pt_deploy_oracleclient { $oracleclient_tag:
          ensure                    => $ensure,
          deploy_user               => $oracle_install_user,
          deploy_user_group         => $oracle_install_group,
          archive_file              => $oracleclient_archive_file,
          deploy_location           => $oracleclient_location,
          oracle_inventory_location => $inventory_location,
          oracle_inventory_user     => $oracle_install_user,
          oracle_inventory_group    => $oracle_install_group,
          redeploy                  => $redeploy,
          remove                    => $oracleclient_remove,
          patch_list                => $oracleclient_patches_list,
        }
      }
      else {
        $deploy_oracleclient = false
      }
    }
    $pshome_hiera = hiera('ps_home')
    $pshome_extract_only = $pshome_hiera['extract_only']
    $extract_only = str2bool($pshome_extract_only)
    notice ("PS Home extract only flag: ${extract_only}")

    $pshome_unicode_db = $pshome_hiera['unicode_db']
    $unicode_db = str2bool($pshome_unicode_db)
    notice ("PS Home unicode db flag: ${unicode_db}")

    $tools_patches = hiera('tools_patches', '')
    if ($tools_patches) and ($tools_patches != '') {
      notice ("Tools patches exists")
      $tools_patches_list = values($tools_patches)
    }
    else {
      notice ("Tools patches do not exists")
      $tools_patches_list = undef
    }

    # deploy each Tools component
    pt_deploy_pshome { $pshome_tag:
      ensure            => $ensure,
      deploy_user       => $tools_install_user,
      deploy_user_group => $tools_install_group,
      db_type           => $db_type,
      archive_file      => $pshome_archive_file,
      deploy_location   => $pshome_location,
      extract_only      => $extract_only,
      unicode_db        => $unicode_db,
      redeploy          => $redeploy,
      remove            => $pshome_remove,
      patch_list        => $tools_patches_list,
    }

    if $deploy_pshome_only == false {
      if ($::kernel != 'AIX') {
      $jdk_patches = hiera('jdk_patches', '')
      if ($jdk_patches) and ($jdk_patches != '') {
        notice ("JDK patches exists")
        $jdk_patches_list = values($jdk_patches)
      }
      else {
        notice ("JDK  patches do not exist")
        $jdk_patches_list = undef
      }

      pt_deploy_jdk { $jdk_tag:
        ensure            => $ensure,
        deploy_user       => $tools_install_user,
        deploy_user_group => $tools_install_group,
        archive_file      => $jdk_archive_file,
        deploy_location   => $jdk_location,
        redeploy          => $redeploy,
        remove            => $jdk_remove,
        patch_list        => $jdk_patches_list,
      }
      }
	  
      $weblogic_patches = hiera('weblogic_patches', '')
      if ($weblogic_patches) and ($weblogic_patches != '') {
        notice ("Weblogic patches exists")
        $weblogic_patches_list = values($weblogic_patches)
      }
      else {
        notice ("Weblogic patches do not exist")
        $weblogic_patches_list = undef
      }
      pt_deploy_weblogic { $weblogic_tag:
        ensure                    => $ensure,
        deploy_user               => $tools_install_user,
        deploy_user_group         => $tools_install_group,
        archive_file              => $weblogic_archive_file,
        deploy_location           => $weblogic_location,
        oracle_inventory_location => $inventory_location,
        oracle_inventory_user     => $oracle_install_user,
        oracle_inventory_group    => $oracle_install_group,
        jdk_location              => $jdk_location,
        redeploy                  => $redeploy,
        remove                    => $weblogic_remove,
        patch_list                => $weblogic_patches_list,
      }
      $tuxedo_patches = hiera('tuxedo_patches', '')
      if ($tuxedo_patches) and ($tuxedo_patches != '') {
        notice ("Tuxedo patches exists")
        $tuxedo_patches_list = values($tuxedo_patches)
      }
      else {
        notice ("Tuxedo patches do not exist")
        $tuxedo_patches_list = undef
      }
      pt_deploy_tuxedo { $tuxedo_tag:
        ensure                    => $ensure,
        deploy_user               => $tools_install_user,
        deploy_user_group         => $tools_install_group,
        archive_file              => $tuxedo_archive_file,
        deploy_location           => $tuxedo_location,
        oracle_inventory_location => $inventory_location,
        oracle_inventory_user     => $oracle_install_user,
        oracle_inventory_group    => $oracle_install_group,
        redeploy                  => $redeploy,
        remove                    => $tuxedo_remove,
        patch_list                => $tuxedo_patches_list,
        jdk_location              => $jdk_location,
      }
      if $ohs_location {
        $deploy_ohs = true

        if $ensure == present {
          $ohs_archive_file   = get_matched_file($tools_archive_location,
                                               $ohs_tag)
          if $ohs_archive_file == '' {
            fail("Unable to locate archive (tgz) file for OHS in ${tools_archive_location}")
          }
        }
        pt_deploy_ohs { $ohs_tag:
          ensure                    => $ensure,
          deploy_user               => $tools_install_user,
          deploy_user_group         => $tools_install_group,
          archive_file              => $ohs_archive_file,
          deploy_location           => $ohs_location,
          oracle_inventory_location => $inventory_location,
          oracle_inventory_user     => $oracle_install_user,
          oracle_inventory_group    => $oracle_install_group,
          jdk_location              => $jdk_location,
          redeploy                  => $redeploy,
          remove                    => $ohs_remove,
        }
      }
      else {
        $deploy_ohs = false
      }
      # COBOL SECTION
      #  1. retrieve cobol info from hiera
      #  2. create cobol license file
      #  3. install and license cobol compiler ( pt_deploy_cobol )
      #  4. delete cobol license file
      #
      # RETRIEVE cobol information from hiera
      $cobol_hiera          = hiera('cobol', '')
      if ($cobol_hiera) and ($cobol_hiera != '') {
        $deploy_cobol       = true

        $cobol_location     = $cobol_hiera['location']
        $cobol_license_sn   = $cobol_hiera['license_serial_number']
        $cobol_license_key  = $cobol_hiera['license_key']

        if $ensure == present {
          $cobol_archive_file   = get_matched_file($tools_archive_location, $cobol_tag)
          if $cobol_archive_file == '' {
            fail("Unable to locate archive (tgz) file for COBOL in ${cobol_archive_location}")
          }
          if ($cobol_license_sn) and ($cobol_license_sn != '') and ($cobol_license_key) and ($cobol_license_key != '') {
            # CREATE cobol license file /tmp/cobol_license.lic
            $cobol_license_file = 'cobol_license.lic'
            file { $cobol_license_file:
              path    => "/tmp/${cobol_license_file}",
              ensure  => file,
              owner   => 'root',
              group   => 'root',
              mode    => '0755',
              content => "i\n$cobol_license_sn\n$cobol_license_key\n",
            }
            # INSTALL cobol compiler, lmf, and install license
            pt_deploy_cobol { $cobol_tag:
              ensure          => $ensure,
              archive_file    => $cobol_archive_file,
              deploy_location => $cobol_location,
              license_file    => "/tmp/${cobol_license_file}",
            }
            # DELETE cobol license file /tmp/cobol_license.lic
            exec { 'delete_cobol_license_file':
              command => "/bin/rm -f /tmp/${cobol_license_file} 2>/dev/null 1>/dev/null",
            }
          }
          else {
            # INSTALL cobol compiler, lmf, and install license
            pt_deploy_cobol { $cobol_tag:
              ensure          => $ensure,
              archive_file    => $cobol_archive_file,
              deploy_location => $cobol_location,
            }
          }
        }
        else {
          pt_deploy_cobol { $cobol_tag:
            ensure          => $ensure,
            archive_file    => $cobol_archive_file,
            deploy_location => $cobol_location,
          }
        }
      }
      else {
        $deploy_cobol = false
      }
      if $ensure == present {
        if ($deploy_oracleclient == true) and ($deploy_ohs == true) {
          if ($deploy_cobol == true) {
					if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
          Pt_deploy_weblogic[$weblogic_tag] ->
          Pt_deploy_tuxedo[$tuxedo_tag] ->
          Pt_deploy_ohs[$ohs_tag] ->
            Pt_deploy_oracleclient[$oracleclient_tag] ->
            Pt_deploy_cobol[$cobol_tag]
          }
          else {
            Pt_deploy_pshome[$pshome_tag] ->
            Pt_deploy_jdk[$jdk_tag] ->
            Pt_deploy_weblogic[$weblogic_tag] ->
            Pt_deploy_tuxedo[$tuxedo_tag] ->
            Pt_deploy_ohs[$ohs_tag] ->
						Pt_deploy_oracleclient[$oracleclient_tag] ->
						Pt_deploy_cobol[$cobol_tag]
        }
				}
				else {
				    if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_ohs[$ohs_tag] ->
						Pt_deploy_oracleclient[$oracleclient_tag]
					}
					else {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_jdk[$jdk_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_ohs[$ohs_tag] ->
						Pt_deploy_oracleclient[$oracleclient_tag]
					}
				}
			}
			elsif $deploy_oracleclient == true {
				if ($deploy_cobol == true) {
					if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_oracleclient[$oracleclient_tag] ->
						Pt_deploy_cobol[$cobol_tag]
					}
					else {		
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_jdk[$jdk_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_oracleclient[$oracleclient_tag] ->
						Pt_deploy_cobol[$cobol_tag]
					}
				}
				else {
					if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_oracleclient[$oracleclient_tag]
					}
					else {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_jdk[$jdk_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_oracleclient[$oracleclient_tag]
					}					
				}
			}
			elsif $deploy_ohs == true {
				if ($deploy_cobol == true) {
					if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_ohs[$ohs_tag] ->
						Pt_deploy_cobol[$cobol_tag]
					}
					else {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_jdk[$jdk_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_ohs[$ohs_tag] ->
						Pt_deploy_cobol[$cobol_tag]					
					}
				}
				else {
					if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_ohs[$ohs_tag]
					}
					else {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_jdk[$jdk_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_ohs[$ohs_tag]					
					}
				}
			}
			else {
				if ($deploy_cobol == true) {
					if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_cobol[$cobol_tag]
					}
					else {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_jdk[$jdk_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag] ->
						Pt_deploy_cobol[$cobol_tag]					
					}
				}
				else {
					if ($::kernel == 'AIX') {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag]
					}
					else {
						Pt_deploy_pshome[$pshome_tag] ->
						Pt_deploy_jdk[$jdk_tag] ->
						Pt_deploy_weblogic[$weblogic_tag] ->
						Pt_deploy_tuxedo[$tuxedo_tag]				
					}
          }
        }
      }
      elsif $ensure == absent {
        if ($deploy_oracleclient == true) and ($deploy_ohs == true) {
				if ($::kernel == 'AIX') {
          Pt_deploy_oracleclient[$oracleclient_tag] ->
          Pt_deploy_ohs[$ohs_tag] ->
          Pt_deploy_tuxedo[$tuxedo_tag] ->
          Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
				else {
					Pt_deploy_oracleclient[$oracleclient_tag] ->
					Pt_deploy_ohs[$ohs_tag] ->
					Pt_deploy_tuxedo[$tuxedo_tag] ->
					Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_jdk[$jdk_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
			}
			elsif $deploy_oracleclient == true {
				if ($::kernel == 'AIX') {
					Pt_deploy_oracleclient[$oracleclient_tag] ->
					Pt_deploy_tuxedo[$tuxedo_tag] ->
					Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
				else {
					Pt_deploy_oracleclient[$oracleclient_tag] ->
					Pt_deploy_tuxedo[$tuxedo_tag] ->
					Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_jdk[$jdk_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
			}
			elsif $deploy_ohs == true {
				if ($::kernel == 'AIX') {
					Pt_deploy_ohs[$ohs_tag] ->
					Pt_deploy_tuxedo[$tuxedo_tag] ->
					Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
				else {
					Pt_deploy_ohs[$ohs_tag] ->
					Pt_deploy_tuxedo[$tuxedo_tag] ->
					Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_jdk[$jdk_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
			}
			else {
				if ($::kernel == 'AIX') {
					Pt_deploy_tuxedo[$tuxedo_tag] ->
					Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
				else {
					Pt_deploy_tuxedo[$tuxedo_tag] ->
					Pt_deploy_weblogic[$weblogic_tag] ->
					Pt_deploy_jdk[$jdk_tag] ->
					Pt_deploy_pshome[$pshome_tag]
				}
        }
      }
    }
    else {
      Pt_deploy_pshome[$pshome_tag]
    }
    if $ensure == present {
      file { $pshome_location:
        ensure  => directory,
        require => Pt_deploy_pshome[$pshome_tag],
      }
    }
  }
