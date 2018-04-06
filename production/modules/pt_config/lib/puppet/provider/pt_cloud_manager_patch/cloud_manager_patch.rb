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

Puppet::Type.type(:pt_cloud_manager_patch).provide :cloud_manager_patch do
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

  def exists?
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end

    @property_hash[:ensure] = :absent
    return false
  end

  def create

    Puppet.debug("In cloudmanager patching create")
    patch_type       = resource[:patch_type]
    if "#{patch_type}" == "file"
      patch_cloudmanager_file_type()
    else
      Puppet.debug("Patch type [#{patch_type}] does not supported")
    end

    @property_hash[:ensure] = :present

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error,
        "Unable to do Cloud Manager patching: #{e.message}"
  end

  def destroy
    Puppet.debug("In cloudmanager patching destroy")

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

  def patch_cloudmanager_file_type
    Puppet.debug("In cloudmanager patching file type started")
    os_user           = resource[:os_user]
    target_path       = resource[:patch_target]
    patch_source      = resource[:patch_source]
    patch_mode        = resource[:patch_mode]

    Puppet.debug("os_user=#{os_user}")
  
    if File.exists?(patch_source) == true 
      # make sure the target file directory exists
      target_dir_name = File.dirname(target_path)
      if File.exists?(target_dir_name) == false
        FileUtils.mkpath(target_dir_name)
      end
      FileUtils.cp_r(patch_source, target_path)
      FileUtils.chmod_R(patch_mode, target_dir_name)
      target_dir_stat = File.stat(target_dir_name)
      FileUtils.chown_R(os_user, target_dir_stat.gid, target_dir_name)
    else
      Puppet.debug("Source file for patching [#{patch_source}] does not exist")
    end
    Puppet.debug("In cloudmanager patching file type completed")
  end
end

