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

Puppet::Type.type(:pt_deploy_ohs).provide :deploy_ohs,
                  :parent => Puppet::Provider::DeployArchive do
  include ::PtDeployUtils::Validations
  include ::PtDeployUtils::Database

  if Facter.value(:osfamily) != 'windows'
    commands :extract_cmd =>  'tar'
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
    ohs_archive_dir = Dir.mktmpdir(['ohs', 'dir'], deploy_parent_location)
    FileUtils.chmod(0755, ohs_archive_dir)

    Puppet.debug("Deploying archive #{archive_file} into " + \
                 "#{ohs_archive_dir}")
    deploy_archive(archive_file, ohs_archive_dir,
                   deploy_user, deploy_group)

    # create the oracle inventory if needed
    inventory_location = resource[:oracle_inventory_location]
    inventory_user = resource[:oracle_inventory_user]
    inventory_group = resource[:oracle_inventory_group]
    checkcreate_oracle_inventory(inventory_location,
                                 inventory_user, inventory_group)

    # paste the OHS installation

    if Facter.value(:osfamily) == 'windows'
      cmd_prefix = ''
      cmd_ext = 'cmd'
      cmd_suffix = ''
      oracle_inv_dir = get_oracle_inventory()
      inv_cmd_opt = ''

    else
      cmd_prefix = "su - #{deploy_user} -c \""
      cmd_ext = 'sh'
      cmd_suffix = "\""
      oracle_inv_dir = inventory_location

      oracle_base = File.dirname(deploy_location)
      # change the oracle base ownership
      user_id = Etc.getpwnam(deploy_user).uid
      group_id = Etc.getgrnam(deploy_group).gid

      FileUtils.makedirs(oracle_base)
      inv_cmd_opt = "-invPtrLoc #{inventory_location}/oraInst.loc"
    end
    # run the ohs tool pasteBinary to copy the ohs to the deploy
    #  location
    jdk_location = resource[:jdk_location]

    fact_kernel = Facter.value(:kernel)
    if (fact_kernel == 'Linux') or (fact_kernel == 'SunOS') or (fact_kernel == 'HP-UX')
      ENV['T2P_JAVA_OPTIONS'] = "-d64 -Djava.io.tmpdir=#{ohs_archive_dir}"
    end

    Puppet.debug("Running the ohs tool to copy the ohs home " + \
                 "to #{deploy_location}")
    oracle_home_name = "OraOHS1213Home"
    paste_cmd = "#{cmd_prefix}#{ohs_archive_dir}/pasteBinary." + \
                "#{cmd_ext} -javaHome #{jdk_location} -archiveLoc " + \
                "#{ohs_archive_dir}/pt-ohs-copy.jar #{inv_cmd_opt} " + \
                "-targetMWHomeLoc #{deploy_location} -targetOracleHomeName #{oracle_home_name} " + \
                "-executeSysPrereqs false -silent true -logDirLoc #{ohs_archive_dir}#{cmd_suffix}"
    Puppet.debug("OHS paste command #{paste_cmd}")

    begin
      Puppet::Util::Execution.execute(paste_cmd, :failonfail => true)
      logs_dir = File.join(deploy_location, 'logs')
      FileUtils.mkdir_p(logs_dir) unless File.exists?( logs_dir)
      FileUtils.chown(user_id, group_id, logs_dir)
      FileUtils.chmod_R(0775, deploy_location)
      Puppet.debug('OHS installation copied successfully')
    rescue Puppet::ExecutionFailure => e
      cleanup_installation(oracle_home_name)
      raise Puppet::ExecutionFailure, "OHS installation copying failed: #{e.message}"
    ensure
      FileUtils.remove_entry(ohs_archive_dir)
    end
  end

  def pre_delete()
    ohs_home = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    inventory_location = resource[:oracle_inventory_location]

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
    deinstall_cmd_path = File.join(ohs_home, 'oui', 'bin', deinstall_cmd)
    deinstall_cmd = "#{cmd_prefix}#{deinstall_cmd_path} -silent -nowait " + \
                    "-ignoreSysPrereqs ORACLE_HOME=#{ohs_home}#{cmd_suffix}"
    Puppet.debug("OHS deinstall command #{deinstall_cmd}")

    begin
      Puppet::Util::Execution.execute(deinstall_cmd, :failonfail => true)
      Puppet.debug("OHS home #{ohs_home} deinstalled successfully")
    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "OHS home #{ohs_home} deinstall failed: #{e.message}"
    end
  end

  def cleanup_installation(oracle_home_name)
    deploy_location = resource[:deploy_location]
    inventory_location = resource[:oracle_inventory_location]

    begin
      # remove the install directory
      FileUtils.rm_rf(deploy_location)

      # remove the entry from inventory file if present
      if Facter.value(:osfamily) == 'windows'
        oracle_inv_dir = get_oracle_inventory()
      else
        oracle_inv_dir = inventory_location
      end
      if oracle_inv_dir.nil? == false
        oracle_home_re = Regexp.new "#{oracle_home_name}"
        oracle_inv_file = File.join(oracle_inv_dir, 'ContentsXML', 'inventory.xml')
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
      if Facter.value(:osfamily) == 'windows'
        # remove the registry entry if present
        system("REG DELETE HKEY_LOCAL_MACHINE\\SOFTWARE\\ORACLE\\KEY_#{oracle_home_name} /f >NUL 2>&1")
      end
    rescue
      Puppet.debug("Cleanup of OHS installation failed.")
    end
  end
end
