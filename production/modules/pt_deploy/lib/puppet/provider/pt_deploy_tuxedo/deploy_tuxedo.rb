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
require 'pt_deploy_utils/validations'
require 'pt_deploy_utils/database'

if Facter.value(:osfamily) == 'windows'
  require 'zlib'
  require 'archive/tar/minitar'
  include Archive::Tar

  require 'win32/registry'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_deploy_tuxedo).provide :deploy_tuxedo,
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
  #  1. need to determine what facter returns for osfamily on HP-UX   sep 09/30/2016
  #  2. need to determine if unzip is available on HP-UX              sep 09/30/2016
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
    end
  end

  def post_create()
    # create the oracle inventory if needed
    inventory_location = resource[:oracle_inventory_location]
    inventory_user = resource[:oracle_inventory_user]
    inventory_group = resource[:oracle_inventory_group]

    inventory_location = checkcreate_oracle_inventory(inventory_location,
                                 inventory_user, inventory_group)

    tuxedo_home = resource[:deploy_location]
    tuxedo_home_name = 'OraTux1222Home'

    tux_temp_dir = Dir.mktmpdir
    FileUtils.chmod(0755, tux_temp_dir)

    oracle_base = File.dirname(tuxedo_home)

    # clone the tuxedo home
    if Facter.value(:osfamily) == 'windows'
      cmd_prefix = ''
      clone_cmd = 'setup.exe'
      cmd_suffix = ''
      inv_cmd_opt = ''

      tuxedo_home = tuxedo_home.gsub('/', '\\')
      oracle_base = oracle_base.gsub('/', '\\')

      #FileUtils.chmod_R(0755, oracle_base)
      # give full control to 'Administrators'
      #  TODO: need to check why the chmod_R is not working
      #perm_cmd = "icacls #{tuxedo_home} /grant Administrators:F /T > NUL"
      perm_cmd = "icacls #{tuxedo_home} /grant *S-1-5-32-544:F /T > NUL"
      system(perm_cmd)
      if $? == 0
        Puppet.debug('Tuxedo permissions updated successfully')
      else
        cleanup_installation(tuxedo_home_name)
        raise Puppet::ExecutionFailure, "Tuxedo permissions update failed"
      end
    else
      deploy_user = resource[:deploy_user]
      deploy_group = resource[:deploy_user_group]

      # change ownership of the parent directory
      user_id = Etc.getpwnam(deploy_user).uid
      group_id = Etc.getgrnam(deploy_group).gid
      FileUtils.chown(user_id, group_id, oracle_base)

      cmd_prefix = "su - #{deploy_user} -c \""
      clone_cmd = 'runInstaller'
      cmd_suffix = "\""

      inv_cmd_opt = "-invPtrLoc #{inventory_location}/oraInst.loc"
    end
    jdk_location = resource[:jdk_location]
    # clone oracle home
    clone_cmd_path = File.join(tuxedo_home, 'oui', 'bin', clone_cmd)
    clone_cmd = "#{cmd_prefix}#{clone_cmd_path} " + \
                "-silent -clone -waitforcompletion -nowait " + \
                 "-jreLoc #{jdk_location}  " + \
                "#{inv_cmd_opt} ORACLE_HOME=#{tuxedo_home} " + \
                "ORACLE_HOME_NAME=#{tuxedo_home_name} " + \
                "TLISTEN_PASSWORD=password#{cmd_suffix}"
    Puppet.debug("Tuxedo clone home command #{clone_cmd}")

    begin
      Puppet::Util::Execution.execute(clone_cmd, :failonfail => true)
      Puppet.debug('Tuxedo home cloning successfully')
    rescue Exception => ex
      cleanup_installation(tuxedo_home_name)
      raise Puppet::ExecutionFailure, "Tuxedo home cloning failed, error message: [#{ex.message}]"
    end

    # install tuxedo patches if specified
    patch_list = resource[:patch_list]
    if ! patch_list.nil?
      patch_list = [patch_list] unless patch_list.is_a? Array
      patch_list.each do |patch|
        Puppet.debug("Installing Tuxedo patch #{patch}")

        tuxedo_patch_dir = Dir.mktmpdir(['tuxedopatch', 'dir'], tuxedo_home)
        FileUtils.chmod(0755, tuxedo_patch_dir)

        if Facter.value(:osfamily) == 'windows'
          Puppet.debug("Extracting Tuxedo patch on Windows platform")

          extract_zip_script = generate_windows_unzip_script(patch, tuxedo_patch_dir)
          system("powershell -File #{extract_zip_script}")
          if $? == 0
            Puppet.debug("Extraction of Tuxedo patch #{patch} successful")
          else
            raise Puppet::ExecutionFailure, "Extraction of Tuxedo patch #{patch} failed"
          end
        else
          Puppet.debug("Extracting Tuxedo patch on Non Windows platform")
          if Facter.value(:kernel) == 'AIX'
            system("cd #{tuxedo_patch_dir} && gunzip -r #{patch} -c | tar xf -")
          else
            unzip_cmd('-d', tuxedo_patch_dir, patch)
          end
          change_ownership(deploy_user, deploy_group, tuxedo_patch_dir)
        end
        # get the patch number
        tuxedo_patch_num = Dir.glob("#{tuxedo_patch_dir}/*.zip")[0]
        tuxedo_patch_num = File.basename(tuxedo_patch_num)
        Puppet.debug('Installing Tuxedo patch ' + tuxedo_patch_num)

        if Facter.value(:osfamily) == 'windows'
          Puppet.debug("Installing Tuxedo patch #{patch} on Windows Platform")

          # stop the Tuxedo services
          tuxedo_version = "12.2.2.0.0_VS2015"
          tuxedo_listener_service = "TUXEDO " + tuxedo_version + " Listener on Port 3050"
          Puppet.debug("Stopping Tuxedo Listener service [#{tuxedo_listener_service}]")
          tuxedo_listener_service_stop_cmd = "net stop \"#{tuxedo_listener_service}\""
          system(tuxedo_listener_service_stop_cmd)
          if $? == 0
            Puppet.debug("Stopping of Tuxedo listener service #{tuxedo_listener_service} successful")
          else
            Puppet.debug("Stopping of Tuxedo listener service #{tuxedo_listener_service} failed")
          end
          tuxedo_procmgr_service = "ORACLE ProcMGR V" + tuxedo_version
          Puppet.debug("Stopping Tuxedo ProcManager service [#{tuxedo_procmgr_service}]")
          tuxedo_procmgr_service_stop_cmd = "net stop \"#{tuxedo_procmgr_service}\""
          system(tuxedo_procmgr_service_stop_cmd)
          if $? == 0
            Puppet.debug("Stopping of Tuxedo ProcManager service #{tuxedo_procmgr_service} successful")
          else
            Puppet.debug("Stopping of Tuxedo ProcManager service #{tuxedo_procmgr_service} failed")
          end
          # setup the environment to apply the patch
          ENV['ORACLE_HOME'] = tuxedo_home
          ENV['TUXDIR']      = tuxedo_home

          platform_id = 233
          ENV['OPATCH_PLATFORM_ID'] = platform_id.to_s

          tuxedo_opatch_cmd = "#{tuxedo_home}\\OPatch\\opatch.bat"

          tuxedo_patch_dir = tuxedo_patch_dir.gsub('/', '\\')
          patch_response_file = "#{tuxedo_patch_dir}\\opatch.rsp"

          target = open(patch_response_file, 'w')
          target.puts("joe@foo.com")
          target.puts("")
          target.puts("")
          target.puts("")
          target.close()
          File.chmod(0755, patch_response_file)

          patch_apply_cmd = "cd #{tuxedo_patch_dir} && #{tuxedo_opatch_cmd} apply #{tuxedo_patch_num} < #{patch_response_file}"
          system(patch_apply_cmd)
          if $? == 0
            Puppet.debug("Tuxedo Patch #{tuxedo_patch_num} install successful")
          else
            Puppet.debug("Tuxedo Patch #{tuxedo_patch_num} install failed")
          end
          # start the services
          Puppet.debug("Starting Tuxedo ProcManager service [#{tuxedo_procmgr_service}]")
          tuxedo_procmgr_service_start_cmd = "net start \"#{tuxedo_procmgr_service}\""
          system(tuxedo_procmgr_service_start_cmd)
          if $? == 0
            Puppet.debug("Starting of Tuxedo ProcManager service #{tuxedo_procmgr_service} successful")
          else
            Puppet.debug("Starting of Tuxedo ProcManager service #{tuxedo_procmgr_service} failed")
          end

          Puppet.debug("Starting Tuxedo Listener service [#{tuxedo_listener_service}]")
          tuxedo_listener_service_start_cmd = "net start \"#{tuxedo_listener_service}\""
          system(tuxedo_listener_service_start_cmd)
          if $? == 0
            Puppet.debug("Starting of Tuxedo listener service #{tuxedo_listener_service} successful")
          else
            Puppet.debug("Starting of Tuxedo listener service #{tuxedo_listener_service} failed")
          end
        else
          Puppet.debug("Installing Tuxedo patch #{patch} on Non Windows Platform")

          # setup the environment to apply the patch
          ENV['ORACLE_HOME'] = tuxedo_home
          ENV['TUXDIR']      = tuxedo_home

          patch_apply_cmd = "#{cmd_prefix}cd #{tuxedo_patch_dir} && #{tuxedo_home}/OPatch/opatch " + \
                           " apply -silent #{inv_cmd_opt} #{tuxedo_patch_num}#{cmd_suffix}"
          begin
            Puppet.debug("Tuxedo patch apply command #{patch_apply_cmd}")
            Puppet::Util::Execution.execute(patch_apply_cmd, :failonfail => true)
            Puppet.debug('Tuxedo patch installation successfully')
          rescue Puppet::ExecutionFailure => e
            Puppet.debug("Tuxedo patch installation failed: #{e.message}")
            raise Puppet::Error, "Installation of Tuxedo patch #{patch} failed: #{e.message}"
          ensure
            FileUtils.remove_entry(tuxedo_patch_dir)
          end
        end
      end
    else
      Puppet.debug("No Tuxedo patch specified to install")
    end
  end

  def pre_delete()
    tuxedo_home = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    inventory_location = resource[:oracle_inventory_location]
    tuxedo_home_name = 'OraTux1222Home'

    tux_temp_dir = Dir.mktmpdir
    FileUtils.chmod(0755, tux_temp_dir)

    if Facter.value(:osfamily) == 'windows'
      cmd_prefix = ''
      cmd_suffix = ''
      deinstall_cmd = 'setup.exe'
      inv_cmd_opt = ''
      tmp_dir_cmd = "set TMP=#{tux_temp_dir}"

      tuxedo_home_path = Dir.glob(File.join(tuxedo_home, 'tuxedo*'))[0]

      # get the deinstall command
      deinstall_cmd_path = File.join(tuxedo_home, 'oui', 'bin', deinstall_cmd)
      deinstall_cmd_path = deinstall_cmd_path.gsub('/', '\\')
      tuxedo_home = tuxedo_home.gsub('/', '\\')

      Puppet.debug("Removing tuxipc if present")
      tuxipc_remove_cmd = "TASKKILL /F /IM tuxipc.exe /T >NUL 2>&1"
      system(tuxipc_remove_cmd)
    else
      cmd_prefix = "su - #{deploy_user} -c \""
      cmd_suffix = "\""
      deinstall_cmd = 'runInstaller'

      # get the deinstall command
      deinstall_cmd_path = File.join(tuxedo_home, 'oui', 'bin', deinstall_cmd)

      inv_cmd_opt = "-invPtrLoc #{inventory_location}/oraInst.loc"
      tmp_dir_cmd = "export TMP=#{tux_temp_dir}"
    end
    jdk_location = resource[:jdk_location]

    # deinstall oracle Home
    deinstall_cmd = "#{tmp_dir_cmd} && #{cmd_prefix}#{deinstall_cmd_path}" + \
                    " -silent -deinstall -waitforcompletion -nowait " + \
                    "-jreLoc #{jdk_location}  " + \
                    "#{inv_cmd_opt} ORACLE_HOME=#{tuxedo_home} " + \
                    "\"REMOVE_HOMES={#{tuxedo_home}}\" " + \
                    "ORACLE_HOME_NAME=#{tuxedo_home_name}#{cmd_suffix}"
    Puppet.debug("Tuxedo deinstall home command #{deinstall_cmd}")

    begin
      if Facter.value(:osfamily) == 'windows'
        system(deinstall_cmd)
      else
        Puppet::Util::Execution.execute(deinstall_cmd, :failonfail => true)
      end
      Puppet.debug("Tuxedo home #{tuxedo_home} deinstall successfully")
    rescue Exception => ex
      raise Puppet::ExecutionFailure, "Tuxedo home #{tuxedo_home} deinstall failed, " +\
                           "error message: [#{ex.message}]"
    ensure
      FileUtils.remove_entry(tux_temp_dir)
    end

    Puppet.debug("Tuxedo home path: #{tuxedo_home_path}")
    if Facter.value(:osfamily) == 'windows' && tuxedo_home_path != nil
      # cleanup the path variable
      begin
        win_env_key = "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment"
        Win32::Registry::HKEY_LOCAL_MACHINE.open(win_env_key,
                                                 Win32::Registry::KEY_ALL_ACCESS) do |reg|
          path_reg_key = "Path"
          begin
            path_value = reg[path_reg_key]
            Puppet.debug("Current PATH environment variable value: #{path_value}")

            tuxedo_bin_path = File.join(tuxedo_home_path, 'bin')
            tuxedo_bin_path = tuxedo_bin_path.gsub('/', '\\')
            path_value = path_value.gsub(';' + tuxedo_bin_path, '')
            Puppet.debug('Modified PATH envionment variable value: ' + path_value)

            tuxedo_jre_server_path = File.join(tuxedo_home_path, 'jre', 'bin', 'server')
            tuxedo_jre_server_path = tuxedo_jre_server_path.gsub('/', '\\')
            path_value = path_value.gsub(';' + tuxedo_jre_server_path, '')
            Puppet.debug('Modified PATH envionment variable value: ' + path_value)

            tuxedo_jre_path = File.join(tuxedo_home_path, 'jre', 'bin')
            tuxedo_jre_path = tuxedo_jre_path.gsub('/', '\\')
            path_value = path_value.gsub(';' + tuxedo_jre_path, '')
            Puppet.debug('Modified PATH envionment variable value: ' + path_value)

            reg[path_reg_key] = path_value
          rescue
            raise Puppet::ExecutionFailure, "Failed to access environment path value in the registry"
          end
        end
      rescue
        raise Puppet::ExecutionFailure, "Failed to access environment key in the registry"
      end
      # stop and remove the Tuxedo services
      remove_tuxedo_services()
    end
  end

  def post_delete()
    if Facter.value(:osfamily) == 'windows'
      # add a delay so that the delete of the deploy location happens
      sleep(5)
    end
    deploy_location = resource[:deploy_location]
    FileUtils.rm_rf(deploy_location)
  end

  def cleanup_installation(oracle_home_name)
    Puppet.debug("Tuxedo install failed, cleaning up the partial install")

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
        system("REG DELETE HKEY_LOCAL_MACHINE\\SOFTWARE\\ORACLE\\TUXEDO\\12.2.2.0.0_VS2015 /f >NUL 2>&1")

        # remove services if present
        remove_tuxedo_services()
      end
    rescue
      Puppet.debug("Cleanup of Tuxedo installation failed.")
    end
  end

  def remove_tuxedo_services()
    if Facter.value(:osfamily) == 'windows'
      tux_version = "12.2.2.0.0_VS2015"
      tux_listener_service = "TUXEDO #{tux_version} Listener on Port 3050"
      tux_listener_service_stop_cmd = "sc stop \"#{tux_listener_service}\" >NUL 2>&1"
      system(tux_listener_service_stop_cmd)
      if $? == 0
        Puppet.debug("Tuxedo listener service stopped successfully")
      else
        Puppet.debug("Tuxedo listener service stopping failed")
      end
      tux_listener_service_del_cmd = "sc delete \"#{tux_listener_service}\" >NUL 2>&1"
      system(tux_listener_service_del_cmd)
      if $? == 0
        Puppet.debug("Tuxedo listener service delete successfully")
      else
        Puppet.debug("Tuxedo listener service delete failed")
      end
      tux_procmgr_service = "ORACLE ProcMGR V#{tux_version}"
      tux_procmgr_service_stop_cmd = "sc stop \"#{tux_procmgr_service}\" >NUL 2>&1"
      system(tux_procmgr_service_stop_cmd)
      if $? == 0
        Puppet.debug("Tuxedo ProcMgr service stopped successfully")
      else
        Puppet.debug("Tuxedo ProcMgr service stopping failed")
      end
      tux_procmgr_service_del_cmd = "sc delete \"#{tux_procmgr_service}\" >NUL 2>&1"
      system(tux_procmgr_service_del_cmd)
      if $? == 0
        Puppet.debug("Tuxedo ProcMgr service delete successfully")
      else
        Puppet.debug("Tuxedo ProcMgr service delete failed")
      end
    end
  end
end
