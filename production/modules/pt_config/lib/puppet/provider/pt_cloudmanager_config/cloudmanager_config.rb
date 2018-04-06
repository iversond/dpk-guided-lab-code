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
require 'pt_comp_utils/webserver'
require 'puppet/provider/pt_utils'

if Facter.value(:osfamily) == 'windows'
  raise Puppet::ExecutionFailure,
        "CM settup is not supported in Windows platform"
end

Puppet::Type.type(:pt_cloudmanager_config).provide :cloudmanager_config do
  include ::PtCompUtils::Validations
  include ::PtCompUtils::WebServer

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

    prcs_domain_name  = resource[:prcs_domain_name]
    ps_cfg_home_dir   = resource[:ps_cfg_home_dir]
    opc_domain_name   = resource[:opc_domain_name]
    opc_user_name     = resource[:opc_user_name]
    cloud_home	      = resource[:cloud_home] 

    ssh_key_file = File.join("#{cloud_home}",'opchome',"#{opc_domain_name}","#{opc_user_name}",'.ssh', 'id_key_rsa')
    if FileTest.exists?(ssh_key_file) == false
      @property_hash[:ensure] = :absent
      Puppet.debug("Cloud Manager #{ssh_key_file} doesnt exist")
      return false
    else
      @property_hash[:ensure] = :present
      Puppet.debug("Cloud Manager Resource exists")
      return true
    end

  end

  def create

    pre_create()
    Puppet.debug("In cloudmanager create")

    create_ssh_keys()
    @property_hash[:ensure] = :present

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error,
        "Unable to do Cloud Manager settings: #{e.message}"
  end

  def destroy
    Puppet.debug("In cloudmanager destroy")

    Puppet.debug("Cloud Manager SSH key removal started")
    prcs_domain_name  = resource[:prcs_domain_name]
    ps_cfg_home_dir   = resource[:ps_cfg_home_dir]
    opc_domain_name   = resource[:opc_domain_name]
    opc_user_name     = resource[:opc_user_name]
    cloud_home        = resource[:cloud_home] #"/home/psadm2/psft/data/cloud/"
    ssh_prv_key_file = File.join("#{cloud_home}",'opchome',"#{opc_domain_name}","#{opc_user_name}",'.ssh', 'id_key_rsa')
    ssh_pub_key_file = File.join("#{cloud_home}",'opchome',"#{opc_domain_name}","#{opc_user_name}",'.ssh', 'id_key_rsa.pub')
    FileUtils.rm_rf(ssh_prv_key_file)
    FileUtils.rm_rf(ssh_pub_key_file)
    Puppet.debug("Cloud Manager SSH key removal completed")

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

  def pre_create
  end

  def create_ssh_keys 

    Puppet.debug("SSH key configuration started")
    os_user           = resource[:os_user]
    prcs_domain_name  = resource[:prcs_domain_name]
    ps_cfg_home_dir   = resource[:ps_cfg_home_dir]
    opc_domain_name   = resource[:opc_domain_name]
    opc_user_name     = resource[:opc_user_name]
    cloud_home        = resource[:cloud_home] #"/home/psadm2/psft/data/cloud/"

    prcs_domain_dir = File.join("#{ps_cfg_home_dir}", 'appserv','prcs',"#{prcs_domain_name}",'files')
    ssh_key_dir = File.join("#{cloud_home}",'opchome',"#{opc_domain_name}","#{opc_user_name}",'.ssh')
    FileUtils.mkdir_p(ssh_key_dir) unless File.exists?(ssh_key_dir)

    prcs_domain_path_stat = File.stat(prcs_domain_dir)
    FileUtils.chown_R(os_user, prcs_domain_path_stat.gid, cloud_home)
    FileUtils.chmod(0755, cloud_home)
    ssh_key_file = File.join("#{ssh_key_dir}", 'id_key_rsa')
    ssh_key_command = "su - #{os_user} -c 'ssh-keygen -t rsa -f #{ssh_key_file} -q -N \"\" '"
    Puppet.debug("SSH key gen command: #{ssh_key_command}")

    log_cmd = "su -s /bin/bash - #{os_user} -c \"mkdir -p LOGS\""  
    begin
        command_output = Puppet::Util::Execution.execute(log_cmd, :failonfail => true)
        command_output = Puppet::Util::Execution.execute(ssh_key_command, :failonfail => true)
        FileUtils.chown_R(prcs_domain_path_stat.uid, prcs_domain_path_stat.gid, ssh_key_dir)
        FileUtils.chmod_R(0500, ssh_key_dir)
        Puppet.debug("SSH Key created successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("SSH Key creation error: #{e.message}, output: #{command_output}")
        raise e
    end
    Puppet.debug("SSH key configuration completed")
  end 
end

