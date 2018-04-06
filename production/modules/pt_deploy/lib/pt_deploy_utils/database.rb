#
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
#

require 'etc'
require 'fileutils'
require 'tempfile'
require 'tmpdir'
require 'open3'

if Facter.value(:osfamily) == 'windows'
  require 'win32/registry'
end

module PtDeployUtils
  module Database

    def self.included(parent)
      parent.extend(Database)
    end

    def checkcreate_oracle_inventory(inventory_location,
                                     inventory_user, inventory_group)
      inv_dir = get_oracle_inventory()
      if inv_dir.nil?

        if Facter.value(:osfamily) == 'windows'
          win_oracle_key = "SOFTWARE\\ORACLE"

          inv_dir = "#{ENV['SYSTEMDRIVE']}\\Program Files\\Oracle\\Inventory"
          inst_loc_key = "inst_loc"
          begin
            Win32::Registry::HKEY_LOCAL_MACHINE.open(win_oracle_key,
                                    Win32::Registry::KEY_ALL_ACCESS) do |reg|
              begin
                inv_dir = reg[inst_loc_key]
              rescue
                # insert the inst_loc value into registry
                reg[inst_loc_key] = inv_dir
              end
            end
          rescue
            # create the oracle registry key
            Win32::Registry::HKEY_LOCAL_MACHINE.create(win_oracle_key) do |reg|
              reg[inst_loc_key] = inv_dir
            end
          end
        else
          inv_dir = inventory_location

          # create the inventory directory
          Puppet.debug("Creating inventory directory #{inventory_location}")
          FileUtils.makedirs(inventory_location)

          inventory_pointer_file = "#{inventory_location}/oraInst.loc"
          if File.exists?(inventory_pointer_file) == false
            target = File.new(inventory_pointer_file, 'w')
            target.puts("inventory_loc=#{inv_dir}")
            target.puts("inst_group=#{inventory_group}")
            target.close
            FileUtils.chmod(0775, inventory_pointer_file)
          end

          FileUtils.makedirs(File.join(inv_dir, 'logs'))

        end
        oracle_inv_file = File.join(inv_dir, 'ContentsXML', 'inventory.xml')
        if File.file?(oracle_inv_file) == false
          Puppet.debug("Inventory file #{oracle_inv_file} does not exists")

          FileUtils.makedirs(File.dirname(oracle_inv_file))

          # create a inventory file
          file = File.new(oracle_inv_file, 'w')
          file.puts("<?xml version=\"1.0\" standalone=\"yes\" ?>")
          file.puts("<!-- Copyright (c) 1999, 2014, Oracle. All rights reserved. -->")
          file.puts("<!-- Do not modify the contents of this file by hand. -->")
          file.puts("<INVENTORY>")
          file.puts("<VERSION_INFO>")
          file.puts("   <SAVED_WITH>13.2.0.0.0</SAVED_WITH>")
          file.puts("   <MINIMUM_VER>2.1.0.6.0</MINIMUM_VER>")
          file.puts("</VERSION_INFO>")
          file.puts("<HOME_LIST>")
          file.puts("</HOME_LIST>")
          file.puts("</INVENTORY>")
          file.close

          if Facter.value(:osfamily) != 'windows'
            # change the ownership of the directory
            Puppet.debug("Changing Oracle inventory directory ownership")
            user_id = Etc.getpwnam(inventory_user).uid
            group_id = Etc.getgrnam(inventory_group).gid
            FileUtils.chown_R(user_id, group_id, inv_dir)
            FileUtils.chmod_R(0770, inv_dir)
          end
        end
      end
      return inv_dir
    end

    def clone_oracle_home(oracle_home, deploy_user, deploy_group,
                          inventory_location, type)
      Puppet.debug("Cloning oracle home #{oracle_home}")

      oracle_base = File.dirname(oracle_home)

      if type == 'server'
        oracle_home_name = 'OraDB12cHome'
        group_clone_settings = "oracle_install_OSDBA=#{deploy_group} oracle_install_OSOPER=#{deploy_group}"
      elsif type == 'client'
        oracle_home_name = 'OraClient12cHome'
        group_clone_settings = ''
      else
        raise ArgumentError, "Invalid type #{type} specified for cloning"
      end

      oc_temp_dir = Dir.mktmpdir
      FileUtils.chmod(0755, oc_temp_dir)

      if Facter.value(:osfamily) == 'windows'

        # FileUtils.chmod_R(0755, deploy_location)
        # give full control to 'Administrators'
        #  TODO: need to check why the chmod_R is not working
        #perm_cmd = "icacls #{oracle_home} /grant Administrators:(OI)(CI)F /T > NUL"
        perm_cmd = "icacls #{oracle_home} /grant *S-1-5-32-544:(OI)(CI)F /T > NUL"
        system(perm_cmd)
        if $? == 0
          Puppet.debug("Oracle home #{oracle_home} permissions updated successfully")
        else
          cleanup_installation(type, oracle_home, inventory_location)
          raise Puppet::ExecutionFailure, "Oracle home #{oracle_home} permissions update failed"
        end
        cmd_prefix = ''
        install_cmd = 'setup.exe'
        cmd_suffix = ''
        tmp_dir_cmd = "set TMP=#{oc_temp_dir}"

        # normalize the path's to windows
        inventory_location = inventory_location.gsub('/', '\\')
        oracle_base = oracle_base.gsub('/', '\\')
        oracle_home = oracle_home.gsub('/', '\\')

        group_clone_settings = ''
        inv_cmd_opt = ''
      else
        cmd_prefix = "su - #{deploy_user} -c \""
        install_cmd = 'runInstaller'
        cmd_suffix = "\""
        tmp_dir_cmd = "export TMP=#{oc_temp_dir}"

        # change the oracle base ownership
        user_id = Etc.getpwnam(deploy_user).uid
        group_id = Etc.getgrnam(deploy_group).gid

        FileUtils.chown(user_id, group_id, oracle_base)
        FileUtils.chmod_R(0755, oracle_base)
        inv_cmd_opt = "-invPtrLoc #{inventory_location}/oraInst.loc"

        # Reference: BUG: 22199125
        # On some linux platforms, the Oracle Home clone is corrupting the libclntshcore.so.12.1
        # shared library. After the clone, either this file is missing or is of 0 size. This is a
        # workaround (sort of hack) to overcome this issue. Before cloning, we make a copy of this
        # library and after the cloning go ahead and replace this library with the copy. This
        # will ensure atleast the library is valid
        #
        lib_clntcore_file = File.join(oracle_home, 'lib', 'libclntshcore.so.12.1')
        if File.exists?(lib_clntcore_file)
          FileUtils.copy(lib_clntcore_file, "#{lib_clntcore_file}.orig")
        end
      end
      clone_cmd_path = File.join(oracle_home, 'oui', 'bin', install_cmd)
      clone_cmd = "#{tmp_dir_cmd} && #{cmd_prefix}#{clone_cmd_path} " + \
                  "-silent -waitforcompletion -nowait -clone #{inv_cmd_opt} " + \
                  "ORACLE_BASE=#{oracle_base} ORACLE_HOME=#{oracle_home} " + \
                  "ORACLE_HOME_NAME=#{oracle_home_name} " + \
                  "#{group_clone_settings}#{cmd_suffix}"

      Puppet.debug("Oracle clone command #{clone_cmd}")

      if Facter.value(:osfamily) == 'windows'
        ch_dir = File.join(oracle_home, 'oui', 'bin')
        Open3.popen3(clone_cmd, :chdir=>ch_dir) do |stdin, out, err, wait_thr|
          error_str = err.read

          FileUtils.remove_entry(oc_temp_dir)

          if wait_thr.value.success?
            Puppet.debug("Cloning of oracle Home #{oracle_home} is successfully")
          else
            cleanup_installation(type, oracle_home, inventory_location)
            raise Puppet::ExecutionFailure, "Cloning of oracle home #{oracle_home} " +
                                            "failed, error: #{error_str}"
          end
        end
      else
        Open3.popen3(clone_cmd) do |stdin, out, err|
          stdin.close
          error_str = err.read

          FileUtils.remove_entry(oc_temp_dir)

          # check if the inventory file is updated
          oracle_inv_file = File.join(inventory_location, 'ContentsXML',
                                      'inventory.xml')
          oracle_home_reg = Regexp.new(oracle_home_name)
          if File.readlines(oracle_inv_file).grep(oracle_home_reg).any?
            Puppet.debug("Cloning of oracle Home #{oracle_home} is successfully")

            ora_inst_root = File.join(inventory_location, 'orainstRoot.sh')
            if File.file?(ora_inst_root)
              perm_cmd = "#{ora_inst_root} >/dev/null"
              system(perm_cmd)
            end
            lib_clntcore_file = File.join(oracle_home, 'lib', 'libclntshcore.so.12.1')
            if File.exists?("#{lib_clntcore_file}.orig")
              FileUtils.copy("#{lib_clntcore_file}.orig", lib_clntcore_file)
              FileUtils.remove_file("#{lib_clntcore_file}.orig")
            end
          else
            cleanup_installation(type, oracle_home, inventory_location)
            raise Puppet::ExecutionFailure, "Cloning of oracle home #{oracle_home} " +
                                            "failed, error: #{error_str}"
          end
        end
      end
    end

    def deinstall_oracle_server_home(oracle_home, deploy_user, inventory_location)
      Puppet.debug("Deinstalling oracle server home #{oracle_home}")

      deinstall_response_file, oracle_inv_dir = generate_oracle_server_deinstall_file(oracle_home, inventory_location)
      execute_oracle_deinstall_cmd(oracle_home, deploy_user,
                                   deinstall_response_file)

      if Facter.value(:osfamily) != 'windows'
        # remove the oracle home entry from the inventory file
        #  TODO: my assumption is that deinstall should remove the home from
        #  the oracle inventory. However, its not doing it. For now, manually
        #  remove the oracle home from the inventory file
        oracle_home_re = Regexp.new 'OraDB12cHome'

        oracle_inv_file = File.join(oracle_inv_dir, 'ContentsXML',
                                   'inventory.xml')
        if File.exists?(oracle_inv_file)
          file_content_mod = File.readlines(oracle_inv_file).reject {
            |line| line =~ oracle_home_re
          }
          file_content_mod = [file_content_mod] unless file_content_mod.is_a? Array
          file_out = File.open(oracle_inv_file, "w")
          file_content_mod.each do |file_line|
            file_out.puts(file_line)
          end
          file_out.close
        end
      end
    end


    def deinstall_oracle_client_home(oracle_home, deploy_user, inventory_location)
      Puppet.debug("Deinstalling oracle client home #{oracle_home}")

      deinstall_response_file, oracle_inv_dir = generate_oracle_client_deinstall_file(oracle_home, inventory_location)

      execute_oracle_deinstall_cmd(oracle_home, deploy_user,
                                   deinstall_response_file)

      if Facter.value(:osfamily) != 'windows'
        # remove the oracle home entry from the inventory file
        #  TODO: my assumption is that deinstall should remove the home from
        #  the oracle inventory. However, its not doing it. For now, manually
        #  remove the oracle home from the inventory file
        oracle_home_re = Regexp.new 'OraClient12cHome'

        oracle_inv_file = File.join(oracle_inv_dir, 'ContentsXML',
                                   'inventory.xml')
        if File.exists?(oracle_inv_file)
          file_content_mod = File.readlines(oracle_inv_file).reject {
            |line| line =~ oracle_home_re
          }
          file_content_mod = [file_content_mod] unless file_content_mod.is_a? Array
          file_out = File.open(oracle_inv_file, "w")
          file_content_mod.each do |file_line|
            file_out.puts(file_line)
          end
          file_out.close
        end
      end
    end

    def get_oracle_inventory
      if Facter.value(:osfamily) == 'windows'
        win_oracle_key = "SOFTWARE\\ORACLE"
        inst_loc_key = "inst_loc"
        begin
          Win32::Registry::HKEY_LOCAL_MACHINE.open(win_oracle_key,
                                  Win32::Registry::KEY_ALL_ACCESS) do |reg|
            begin
              oracle_inv_dir = reg[inst_loc_key]

              oracle_inv_file = File.join(oracle_inv_dir, 'ContentsXML',
                                          'inventory.xml')
              # check if the oracle inventory directory exists
              if File.file?(oracle_inv_file)
                return oracle_inv_dir
              else
                return nil
              end
            rescue
              return nil
            end
          end
        rescue
          return nil
        end
      end
      return nil
    end

    def cleanup_installation(type, deploy_location, inventory_location)

      begin
        # remove the install directory
        oracle_base = File.dirname(deploy_location)
        FileUtils.rm_rf(deploy_location)

        if type == 'server'
          oracle_home_name = 'OraDB12cHome'
        elsif type == 'client'
          oracle_home_name = 'OraClient12cHome'
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
        Puppet.debug("Cleanup of Oracle #{type} installation failed.")
      end
    end

    private

    def generate_oracle_client_deinstall_file(oracle_home, inventory_location)
      if Facter.value(:osfamily) == 'windows'
        oracle_inv_dir = get_oracle_inventory()
      else
        oracle_inv_dir = inventory_location
      end
      if (oracle_inv_dir.nil?) or (File.directory?(oracle_inv_dir) == false)
        raise ArgumentError, "Oracle inventory not found, deinstall of oracle " +
                             "home #{oracle_home} cannot be done."
      end
      Puppet.debug("Oracle inventory #{oracle_inv_dir}")

      oracle_base = File.dirname(oracle_home)

      # generate deinstall params file
      temp_dir_name = Dir.tmpdir()
      response_file_path = File.join(temp_dir_name, "deinstall.rsp")
      target = File.open(response_file_path, 'w')

      host_name = Facter.value(:fqdn)
      log_dir = oracle_base

      if Facter.value(:osfamily) == 'windows'
        # normalize the path's to windows
        oracle_inv_dir = oracle_inv_dir.gsub('/', '\\')
        oracle_base = oracle_base.gsub('/', '\\')
        oracle_home = oracle_home.gsub('/', '\\')
        log_dir = log_dir.gsub('/', '\\')
      end
      Puppet.debug("Oracle base: #{oracle_base}")
      Puppet.debug("Oracle home: #{oracle_home}")
      Puppet.debug("Oracle inventory: #{oracle_inv_dir}")
      Puppet.debug("Log dir: #{log_dir}")

      target.puts("ORACLE_BASE=#{oracle_base}")
      target.puts("INVENTORY_LOCATION=#{oracle_inv_dir}")
      target.puts('CRS_HOME=false')
      target.puts('HOME_TYPE=CLIENT')
      target.puts('silent=true')
      target.puts('MinimumSupportedVersion=11.2.0.1.0')
      target.puts('local=true')
      target.puts("LOCAL_NODE=#{host_name}")
      target.puts("ORACLE_HOME=#{oracle_home}")
      target.puts("LOGDIR=#{log_dir}")
      target.puts("ObaseCleanupPtrLoc=#{log_dir}#{File::SEPARATOR}orabase_cleanup.lst")
      target.puts('ORACLE_HOME_VERSION_VALID=true')
      target.close

      return response_file_path, oracle_inv_dir
    end

    def generate_oracle_server_deinstall_file(oracle_home, inventory_location)

      if Facter.value(:osfamily) == 'windows'
        oracle_inv_dir = get_oracle_inventory()
      else
        oracle_inv_dir = inventory_location
      end
      if (oracle_inv_dir.nil?) or (File.directory?(oracle_inv_dir) == false)
        raise ArgumentError, "Oracle inventory not found, deinstall of oracle " +
                             "home #{oracle_home} cannot be done."
      end
      Puppet.debug("Oracle inventory #{oracle_inv_dir}")
      oracle_base = File.dirname(oracle_home)

      # generate deinstall params file
      temp_dir_name = Dir.tmpdir()
      response_file_path = File.join(temp_dir_name, "deinstall.rsp")
      target = File.open(response_file_path, 'w')

      host_name = Facter.value(:fqdn)
      log_dir = File.join(oracle_inv_dir, 'logs')

      if Facter.value(:osfamily) == 'windows'
        # normalize the path's to windows
        oracle_inv_dir = oracle_inv_dir.gsub('/', '\\')
        oracle_base = oracle_base.gsub('/', '\\')
        oracle_home = oracle_home.gsub('/', '\\')
        log_dir = log_dir.gsub('/', '\\')
      end
      Puppet.debug("Oracle base: #{oracle_base}")
      Puppet.debug("Oracle home: #{oracle_home}")
      Puppet.debug("Oracle inventory: #{oracle_inv_dir}")
      Puppet.debug("Log dir: #{log_dir}")

      target.puts("ORACLE_HOME=#{oracle_home}")
      target.puts("LOGDIR=#{log_dir}")
      target.puts("ORACLE_BASE=#{oracle_base}")
      target.puts('OLD_ACTIVE_ORACLE_HOME=')
      target.puts("INVENTORY_LOCATION=#{oracle_inv_dir}")
      if Facter.value(:osfamily) == 'windows'
        target.puts('NETCA_LOCAL_LISTENERS=')
        target.puts('DB_UNIQUE_NAME_LIST=')
        target.puts('COMPS_TO_REMOVE=ode.net,ntoledb,oramts,odp.net,asp.net')
      else
        target.puts('DB_UNIQUE_NAME_LIST=[]')
      end
      target.puts('HOME_TYPE=SIDB')
      target.puts('CRS_HOME=false')
      target.puts('ORACLE_BINARY_OK=true')
      target.puts("LOCAL_NODE=#{host_name}")
      target.puts('local=true')
      target.puts('MinimumSupportedVersion=11.2.0.1.0')
      target.puts('silent=true')
      target.puts('CCR_CONFIG_STATUS=CCR_DEL_HOME')
      target.puts('ORACLE_HOME_VERSION_VALID=true')
      target.close

      return response_file_path, oracle_inv_dir
    end

    def execute_oracle_deinstall_cmd(oracle_home, deploy_user, response_file)

      oracle_base = File.dirname(oracle_home)
      log_dir = oracle_base

      oc_temp_dir = Dir.mktmpdir
      FileUtils.chmod(0777, oc_temp_dir)

      if Facter.value(:osfamily) == 'windows'
        cmd_prefix = ''
        cmd_suffix = ''
        additional_params = ''
        deinstall_cmd = 'deinstall.bat'

        # get the deinstall
        deinstall_cmd_path = File.join(oracle_home, 'deinstall', deinstall_cmd)
        deinstall_cmd_path = deinstall_cmd_path.gsub('/', '\\')
      else
        cmd_prefix = "su - #{deploy_user} -c \""
        cmd_suffix = "\""
        deinstall_cmd = 'deinstall'
        additional_params = "-logdir #{log_dir} -tmpdir #{oc_temp_dir} "
        # get the deinstall
        deinstall_cmd_path = File.join(oracle_home, 'deinstall', deinstall_cmd)
      end

      deinstall_cmd = "#{cmd_prefix}#{deinstall_cmd_path} -silent -local " + \
                      "#{additional_params} -paramfile #{response_file}#{cmd_suffix}"
      Puppet.debug("Oracle deinstall command #{deinstall_cmd}")

      begin
        Puppet::Util::Execution.execute(deinstall_cmd, :failonfail => true)
        Puppet.debug("Oracle home #{oracle_home} deinstalled successfully")
      rescue Puppet::ExecutionFailure => e
        raise Puppet::ExecutionFailure, "Oracle home #{oracle_home} deinstall failed: #{e.message}"
      ensure
        File.delete(response_file)
        FileUtils.chmod(0755, oc_temp_dir)
        FileUtils.remove_entry(oc_temp_dir)
      end
    end

  end
end

