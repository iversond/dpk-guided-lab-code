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
#  Copyright (C) 1988, 2015, Oracle and/or its affiliates.
#  All Rights Reserved.
# ***************************************************************

require 'tempfile'
require 'tmpdir'

require 'pt_comp_utils/validations'
require 'puppet/provider/pt_utils'

if Facter.value(:osfamily) == 'windows'
  raise Puppet::ExecutionFailure,
        "CM settup is not supported in Windows platform"
end

Puppet::Type.type(:pt_cm_fileserver_config).provide :cm_fileserver_config do
  include ::PtCompUtils::Validations

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  mk_resource_methods

  def initialize(value={})
    super(value)
    Puppet.debug("Provider Initialization")
    @property_flush = {}
  end

  @fileserver_hash = {}
  def fileserver_hash=(fileserver_hash)
    #Puppet.debug("Caching Fileserver settings: #{fileserver_hash.inspect}")
    @fileserver_hash = fileserver_hash
  end

  def exists?
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end

    fileserver_mount_path = resource[:fileserver_mount_path]

    mount_file_name = '/proc/mounts'
    if File.readlines("#{mount_file_name}").grep(/#{fileserver_mount_path}/).size > 0
      @property_hash[:ensure] = :present
      Puppet.debug("Cloud Manager mount point #{fileserver_mount_path} exists")
      return true
    else
      @property_hash[:ensure] = :absent
      Puppet.debug("Cloud Manager mount point #{fileserver_mount_path} doesnt exist")
      return false
    end
#    if File.directory?(fileserver_mount_path) == false
#      @property_hash[:ensure] = :absent
#      Puppet.debug("Cloud Manager mount dir #{fileserver_mount_path} doesnt exist")
#      return false
#    else
#      @property_hash[:ensure] = :present
#      Puppet.debug("Cloud Manager mount dir #{fileserver_mount_path} exists")
#      return true
#    end

  end

  def create

    Puppet.debug("In cloudmanager fileserver create")

    configure_file_server()
    @property_hash[:ensure] = :present

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error,
        "Unable to do Cloud Manager settings: #{e.message}"
  end

  def destroy
    Puppet.debug("In cloudmanager Fileserver destroy")

    Puppet.debug("Cloud Manager File server removal started")

    fileserver_mount_path = resource[:fileserver_mount_path]
    fileserver_hostname   = resource[:fileserver_hostname]
    fileserver_dpk_path   = resource[:fileserver_dpk_path]
    
    fs_umount_cmd = "umount -l #{fileserver_mount_path}"
    fs_unmound_fstab_cmd = "sed -i '\\|#{fileserver_hostname}:#{fileserver_dpk_path}|d' /etc/fstab"
    Puppet.debug("Fileserver umount command #{fs_umount_cmd}")
    Puppet.debug("Fileserver fstab command: #{fs_unmound_fstab_cmd}")

    begin
        mount_file_name = '/proc/mounts'
        if File.readlines("#{mount_file_name}").grep(/#{fileserver_mount_path}/).size > 0
          #directory is mounted
          Puppet.debug("Unmounting the #{fileserver_mount_path} directory")
          command_output = Puppet::Util::Execution.execute(fs_umount_cmd, :failonfail => true)
        end
        command_output = Puppet::Util::Execution.execute(fs_unmound_fstab_cmd, :failonfail => true)
        FileUtils.rm_rf(fileserver_mount_path)
        Puppet.debug("File server configurered successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("File server configuration error: #{e.message}, output: #{command_output}")
        raise e
    end
    FileUtils.rm_rf(fileserver_mount_path)
    Puppet.debug("Cloud Manager File server removal completed")

    @property_hash[:ensure] = :absent
    @property_flush.clear
  end

  def flush
    @property_hash = resource.to_hash
  end

  def self.instances
    []
  end

  private

  def configure_file_server

    Puppet.debug("Cloud Manager Fileserver configuration started")
    fileserver_mount_path = resource[:fileserver_mount_path]
    fileserver_hostname   = resource[:fileserver_hostname]
    fileserver_dpk_path   = resource[:fileserver_dpk_path]
    ps_app_home           = resource[:ps_app_home_dir]
    
    FileUtils.mkdir_p(fileserver_mount_path) unless File.exists?(fileserver_mount_path)
    FileUtils.chmod_R(0777, fileserver_mount_path)
    fs_configure_command = "mount -t nfs #{fileserver_hostname}:#{fileserver_dpk_path} #{fileserver_mount_path}"
    fs_mount_fstab_cmd = "echo \"#{fileserver_hostname}:#{fileserver_dpk_path} #{fileserver_mount_path} nfs defaults 0 0\" >> /etc/fstab"
    Puppet.debug("File Server configuration command: #{fs_configure_command}")
    fs_sync_cmd = "su - #{@fileserver_hash[:os_user]} -c 'psae -CT #{@fileserver_hash[:db_type]} -CD #{@fileserver_hash[:db_name]} -CO #{@fileserver_hash[:db_opr_id]} -CP #{@fileserver_hash[:db_opr_pwd]} -CI #{@fileserver_hash[:db_connect_id]} -CW #{@fileserver_hash[:db_connect_pwd]} -R #{@fileserver_hash[:run_control_id]} -AI #{@fileserver_hash[:program_id]}'"  
    fs_sync_mask_cmd = "su - #{@fileserver_hash[:os_user]} -c 'psae -CT #{@fileserver_hash[:db_type]} -CD #{@fileserver_hash[:db_name]} -CO #{@fileserver_hash[:db_opr_id]} -CP ***** -CI #{@fileserver_hash[:db_connect_id]} -CW ***** -R #{@fileserver_hash[:run_control_id]} -AI #{@fileserver_hash[:program_id]}'"  
    Puppet.debug("File Server configuration command: #{fs_configure_command}")
    Puppet.debug("File Server mount command: #{fs_mount_fstab_cmd}")
    Puppet.debug("File Server Sync command: #{fs_sync_mask_cmd}")

    begin
        mount_file_name = '/proc/mounts'
        if File.readlines("#{mount_file_name}").grep(/#{fileserver_mount_path}/).size < 1
          #directory is not mounted
          Puppet.debug("Mounting the #{fileserver_mount_path} directory to Cloud Manager") 
          command_output = Puppet::Util::Execution.execute(fs_configure_command, :failonfail => true)
        end
        command_output = Puppet::Util::Execution.execute(fs_mount_fstab_cmd, :failonfail => true)
        FileUtils.chmod(0777, fileserver_mount_path)
        command_output = Puppet::Util::Execution.execute(fs_sync_cmd, :failonfail => true)
        Puppet.debug("File Server Sync started for #{fileserver_mount_path}/cloud directory")
        FileUtils.rm_rf(File.join(fileserver_mount_path, 'cloud_bk'))
        if File.directory?( File.join(fileserver_mount_path, 'cloud')) == true
          FileUtils.mv(File.join(fileserver_mount_path, 'cloud'), File.join(fileserver_mount_path, 'cloud_bk'))
        end
        FileUtils.cp_r(File.join(ps_app_home, 'cloud'), fileserver_mount_path)
        Puppet.debug("File Server Sync completed for #{fileserver_mount_path}/cloud directory")
        Puppet.debug("File server configurered successfully")
    rescue Puppet::ExecutionFailure => e
    	FileUtils.rm_rf(fileserver_mount_path)
        Puppet.debug("File server configuration error: #{e.message}, output: #{command_output}")
        raise e
    end
    Puppet.debug("Cloud Manager Fileserver configuration completed")

  end
end

