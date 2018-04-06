# ***************************************************************
#  This software and related documentation are provided under a
#  license agreement containing restrictions on use and
#  disclosure and are protected by intellectual property
#  laws. Except as expressly permitted in your license agreement
#  or allowed by law, you may not use, copy, reproduce,
#  translate, broadcast, modify, license, transmit, distribute,
#  exhibit, perform, publish or display any part, in any form or
#  by any means. Reverse engineering, disassembly, or
#  decompilation of this software, unless required by law for
#  interoperability, is prohibited.
#  The information contained herein is subject to change without
#  notice and is not warranted to be error-free. If you find any
#  errors, please report them to us in writing.
#
#  Copyright (C) 1988, 2017, Oracle and/or its affiliates.
#  All Rights Reserved.
# ***************************************************************

require 'puppet/provider/deployarchive'
require 'fileutils'
require 'tmpdir'
require 'etc'
require 'find'
require 'pt_deploy_utils/validations'
require 'pt_deploy_utils/database'

if Facter.value(:osfamily) == 'windows'
  require 'win32/registry'
  include Win32
end

Puppet::Type.type(:pt_deploy_weblogic).provide :deploy_weblogic,
                  :parent => Puppet::Provider::DeployArchive do
  include ::PtDeployUtils::Validations
  include ::PtDeployUtils::Database

  if Facter.value(:osfamily) == 'RedHat'
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end
  if Facter.value(:osfamily) == 'AIX'
    commands :extract_cmd  =>  'gunzip'
  end
  if Facter.value(:osfamily) == 'Solaris'
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end
  # 
  # 1. need to determine what facter returns for osfamily on HP-UX
  # 2. need to determine if unzip available on HP-UX
  #
  if Facter.value(:osfamily) == 'HP-UX'
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end

  mk_resource_methods

  private

  def validate_parameters()
    if Facter.value(:osfamily) != 'windows'
      super()
      deploy_user = resource[:deploy_user]
      deploy_group = resource[:deploy_user_group]
      inventory_location = resource[:oracle_inventory_location]
      inventory_user = resource[:oracle_inventory_user]
      inventory_group = resource[:oracle_inventory_group]

      validate_oracle_inventory_permissions(inventory_location,
                                            inventory_user, inventory_group,
                                            deploy_user, deploy_group)

      jdk_location = resource[:jdk_location]
        if FileTest.directory?(jdk_location) == false
          raise ArgumentError, "JDK directory #{jdk_location} does not exists"
        end
    end
  end

  def pre_create()
  end

  def post_create()
    archive_file = resource[:archive_file]
    deploy_location = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    deploy_group = resource[:deploy_user_group]

    deploy_parent_location = File.dirname(deploy_location)
    weblogic_archive_dir = Dir.mktmpdir(['wl', 'dir'], deploy_parent_location)
    FileUtils.chmod(0755, weblogic_archive_dir)

    Puppet.debug("Deploying archive #{archive_file} into " + \
                 "#{weblogic_archive_dir}")
    deploy_archive(archive_file, weblogic_archive_dir,
                   deploy_user, deploy_group)

    if Facter.value(:osfamily) == 'windows'
      weblogic_archive_dir_win = weblogic_archive_dir.gsub('/', '\\')
      #perm_cmd = "icacls #{weblogic_archive_dir_win} /grant Administrators:F /T > NUL"
      perm_cmd = "icacls #{weblogic_archive_dir_win} /grant *S-1-5-32-544:F /T > NUL"
      system(perm_cmd)
      if $? == 0
        Puppet.debug('Weblogic archive folder permissions updated successfully')
      else
        raise Puppet::Error, "Weblogic archive folder permissions update failed"
      end
    else
      FileUtils.chmod_R(0755, weblogic_archive_dir)
    end

    # create the oracle inventory if needed
    inventory_location = resource[:oracle_inventory_location]
    inventory_user = resource[:oracle_inventory_user]
    inventory_group = resource[:oracle_inventory_group]

    checkcreate_oracle_inventory(inventory_location,
                                 inventory_user, inventory_group)

    # paste the Weblogic installation

    if Facter.value(:osfamily) == 'windows'
      cmd_prefix = ''
      cmd_ext = 'cmd'
      cmd_suffix = ''
      inv_cmd_opt = ''
    else
      cmd_prefix = "su - #{deploy_user} -c \""
      cmd_ext = 'sh'
      cmd_suffix = "\""

      oracle_base = File.dirname(deploy_location)
      # change the oracle base ownership
      user_id = Etc.getpwnam(deploy_user).uid
      group_id = Etc.getgrnam(deploy_group).gid

      FileUtils.makedirs(oracle_base)
      FileUtils.chown(user_id, group_id, oracle_base)
      FileUtils.chmod(0755, oracle_base)

      inv_cmd_opt = "-invPtrLoc #{inventory_location}/oraInst.loc"
    end
    # run the weblogic tool pasteBinary to copy the weblogic to the deploy
    #  location
    jdk_location = resource[:jdk_location]

    fact_kernel = Facter.value(:kernel)
    if (fact_kernel == 'Linux') or (fact_kernel == 'SunOS') or (fact_kernel == 'HP-UX')
      ENV['T2P_JAVA_OPTIONS'] = "-d64 -Djava.io.tmpdir=#{weblogic_archive_dir}"
    end

    Puppet.debug("Running the weblogic tool to copy the weblogic home " + \
                 "to #{deploy_location}")
    oracle_home_name = "OraWL1213Home"
    temp_dir_name = Dir.tmpdir()
    paste_cmd = "#{cmd_prefix}#{weblogic_archive_dir}/pasteBinary." + \
                "#{cmd_ext} -javaHome #{jdk_location} -archiveLoc " + \
                "#{weblogic_archive_dir}/pt-weblogic-copy.jar " + \
                "-targetMWHomeLoc #{deploy_location} -targetOracleHomeName #{oracle_home_name} " + \
                "#{inv_cmd_opt} -executeSysPrereqs false " + \
                "-silent true -logDirLoc #{temp_dir_name}#{cmd_suffix}"
    Puppet.debug("Weblogic paste command #{paste_cmd}")

    begin
      Puppet::Util::Execution.execute(paste_cmd, :failonfail => true)
      if Facter.value(:osfamily) != 'windows'
        FileUtils.chmod_R(0775, deploy_location)
        FileUtils.chmod_R(0775, "#{inventory_location}")
      else
        Find.find(deploy_location) do |path|
          begin
            FileUtils.chmod(0775, path)
          rescue
            Puppet.debug("Ignoring chmod for path #{path}")
          end
        end
      end
      Puppet.debug('Weblogic installation copied successfully')

    rescue Puppet::ExecutionFailure => e
      # cleanup the installation so that the ensuing apply will start from
      # scratch
      Puppet.debug("Weblogic install failed, cleaning up the partial install")
      cleanup_installation(oracle_home_name)
      raise Puppet::ExecutionFailure, "Weblogic installation copying failed: #{e.message}"
    ensure
      FileUtils.remove_entry(weblogic_archive_dir)
    end
    # if patches list exists, install them
    patch_list = resource[:patch_list]
    if ! patch_list.nil?
      patch_list = [patch_list] unless patch_list.is_a? Array
      patch_list.each do |patch|

        Puppet.debug("Extracting Weblogic patch #{patch}")
        Puppet.debug("Installing Weblogic patch #{patch}")

        weblogic_patch_dir = Dir.mktmpdir(['wlpatch', 'dir'], deploy_parent_location)
        FileUtils.chmod(0755, weblogic_patch_dir)

        if Facter.value(:osfamily) == 'windows'
          Puppet.debug("Extracting WebLogic patch on Windows platform")

          #extract_zip_script = generate_windows_unzip_script(patch, weblogic_patch_dir)
          #system("powershell -File #{extract_zip_script}")
          #if $? == 0
          #  Puppet.debug("Extraction of WebLogic patch #{patch} successful")
          #else
          #  raise Puppet::ExecutionFailure, "Extraction of WebLogic patch #{patch} failed"
          #end
        else
          Puppet.debug("Extracting WebLogic patch on Non Windows platform")
          if Facter.value(:kernel) == 'AIX'
            system("cd #{weblogic_patch_dir} && gunzip -r #{patch} -c | tar xf -")
          else
            if Facter.value(:kernel) == 'AIX'
               system("cd #{weblogic_patch_dir} && gunzip -r #{patch} -c | tar xf -")
            else
              unzip_cmd('-d', weblogic_patch_dir, patch)
            end
          end
          change_ownership(deploy_user, deploy_group, weblogic_patch_dir)
        end
        begin
          if Facter.value(:osfamily) != 'windows'
            Puppet.debug("Installing WebLogic patch #{patch}")
            ENV['ORACLE_HOME'] = deploy_location
            Puppet.debug('Oracle Home environment variable' + ENV['ORACLE_HOME'])

            # get the patch number
            weblogic_patch_num = Dir.entries(weblogic_patch_dir).reject {|f| !File.directory?(f) || f.include?('.')}[0]
            Puppet.debug('Installing WebLogic patch number ' + weblogic_patch_num)

            patch_dir = "#{weblogic_patch_dir}/#{weblogic_patch_num}"
            Puppet.debug("Installing Weblogic patch #{weblogic_patch_num} from  #{patch_dir}")

            patch_apply_cmd = "#{cmd_prefix} cd #{patch_dir} && #{deploy_location}/OPatch/opatch " + \
              " apply -silent -jdk #{jdk_location}#{cmd_suffix}"
            Puppet.debug("Weblogic patch apply command #{patch_apply_cmd}")
            Puppet::Util::Execution.execute(patch_apply_cmd, :failonfail => true)
            Puppet.debug('Weblogic patch installation successfully')
          end
        rescue Puppet::ExecutionFailure => e
          Puppet.debug("Weblogic patch installation failed: #{e.message}")
          raise Puppet::Error, "Installation of weblogic patch #{patch} failed: #{e.message}"
        ensure
          FileUtils.remove_entry(weblogic_patch_dir)
        end
      end
    else
      Puppet.debug("No Weblogic patch specified to install")
    end
  end

  def pre_delete()
    weblogic_home = resource[:deploy_location]
    deploy_user = resource[:deploy_user]

    if Facter.value(:osfamily) == 'windows'
      cmd_prefix = ''
      cmd_suffix = ''
      deinstall_cmd = 'deinstall.cmd'
    else
      cmd_prefix = "su - #{deploy_user} -c \""
      cmd_suffix = "\""
      deinstall_cmd = 'deinstall.sh'
    end

    # get the deinstall
    deinstall_cmd_path = File.join(weblogic_home, 'oui', 'bin', deinstall_cmd)
    if FileTest.exist?(deinstall_cmd_path)
      deinstall_cmd = "#{cmd_prefix}#{deinstall_cmd_path} -silent -nowait -ignoreSysPrereqs " + \
                      "ORACLE_HOME=#{weblogic_home}#{cmd_suffix}"
      Puppet.debug("Weblogic deinstall command #{deinstall_cmd}")
      begin
        Puppet::Util::Execution.execute(deinstall_cmd, :failonfail => true)
        Puppet.debug("Weblogic home #{weblogic_home} deinstalled successfully")
      rescue Puppet::ExecutionFailure => e
        raise Puppet::ExecutionFailure, "Weblogic home #{weblogic_home} deinstall failed: #{e.message}"
      end
    end
  end

  def cleanup_installation(oracle_home_name)
    deploy_location = resource[:deploy_location]
    inventory_location = resource[:oracle_inventory_location]

    begin
      if FileTest.directory?(deploy_location)
        # remove the install directory
        FileUtils.rm_rf(deploy_location)
      end

      # remove the entry from inventory file if present
      if Facter.value(:osfamily) == 'windows'
        oracle_inv_dir = get_oracle_inventory()
      else
        oracle_inv_dir = inventory_location
      end
      if oracle_inv_dir.nil? == false
        oracle_inv_file = File.join(oracle_inv_dir, 'ContentsXML', 'inventory.xml')
        file_content_mod = File.readlines(oracle_inv_file).reject { |line| line.include?(oracle_home_name) }
        file_content_mod = [file_content_mod] unless file_content_mod.is_a? Array
        file_out = File.open(oracle_inv_file, "w")
        file_content_mod.each do |file_line|
          file_out.puts(file_line)
        end
        file_out.close
      end
      if Facter.value(:osfamily) == 'windows'
        # remove the registry entry if present
        system("REG DELETE HKEY_LOCAL_MACHINE\\SOFTWARE\\ORACLE\\KEY_#{oracle_home_name} /f >NUL 2>&1")
      end
    rescue
      Puppet.debug("Cleanup of Weblogic installation failed.")
    end
  end

end
