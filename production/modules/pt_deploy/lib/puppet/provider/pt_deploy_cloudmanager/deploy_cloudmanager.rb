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

if Facter.value(:osfamily) == 'windows'
  raise Puppet::ExecutionFailure,
        "CM settup is not supported in Windows platform"
end

Puppet::Type.type(:pt_deploy_cloudmanager).provide :deploy_cloudmanager do

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

    ps_home_dir = resource[:ps_home_dir]
    ca_dir = File.join("#{ps_home_dir}", 'openssl', 'CA')
    if File.directory?(ca_dir) == false
      @property_hash[:ensure] = :absent
      Puppet.debug("{ca_dir} doesnt exist")
      return false
    else
      @property_hash[:ensure] = :present
      Puppet.debug("Resource exists")
      return true
    end
  end

  def create

    pre_create()
    Puppet.debug("In cloudmanager create")


    configure_pet()
    setup_python()
    setup_env_variables()
    setup_cm_repository()

    @property_hash[:ensure] = :present

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error,
        "Unable to do Cloud Manager settings: #{e.message}"
  end

  def destroy
    Puppet.debug("In cloudmanager destroy")
    ps_home_dir       = resource[:ps_home_dir]
    ps_app_home_dir   = resource[:ps_app_home_dir]
    prcs_domain_name  = resource[:prcs_domain_name]
    ps_cfg_home_dir   = resource[:ps_cfg_home_dir]
    opc_domain_name   = resource[:opc_domain_name]
    opc_user_name     = resource[:opc_user_name]
    os_user           = resource[:os_user]

    #Remove PET deployment
    ca_dir = File.join("#{ps_home_dir}", 'openssl', 'CA')
    FileUtils.rm_rf(ca_dir)
    pet_cmd = "sed -i '/export OPENSSL_CONF/d' /etc/profile"
    Puppet.debug("pet_cmd=#{pet_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(pet_cmd, :failonfail => true)
        Puppet.debug("PET details removed sccessfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("PET details removal error: #{e.message}, output: #{command_output}")
        raise e
    end

    #Remove python bits
    lnx_python_dest_path = File.join("#{ps_app_home_dir}", 'cloud', 'lnx_python')
    win_python_dest_path = File.join("#{ps_app_home_dir}", 'cloud', 'win_python')
    FileUtils.rm_rf(lnx_python_dest_path)
    FileUtils.rm_rf(win_python_dest_path)
    python_cmd = "sed -i '/CLOUD_ADMIN_LNX_PYTHON/d' /etc/profile"
    Puppet.debug("python_cmd=#{python_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(python_cmd, :failonfail => true)
        Puppet.debug("Python details removed sccessfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("Python details removal error: #{e.message}, output: #{command_output}")
        raise e
    end

    pythonpath_remove_cmd = "sed -i '/PYTHONPATH/d' /etc/profile"
    pythonhome_remove_cmd = "sed -i '/PYTHONHOME/d' /etc/profile"
    Puppet.debug("pythonpath_remove_cmd=#{pythonpath_remove_cmd}")
    Puppet.debug("pythonhome_remove_cmd=#{pythonhome_remove_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(pythonpath_remove_cmd, :failonfail => true)
        Puppet.debug("PYTHONPATH env detail removed successfully")
        command_output = Puppet::Util::Execution.execute(pythonhome_remove_cmd, :failonfail => true)
        Puppet.debug("PYTHONHOME env detail removed successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("Python related env variables removal error: #{e.message}, output: #{command_output}")
        raise e
    end

    #Remove MOS updation
    mos_cmd = "sed -i -e /updates.oracle.com/d -e /login.oracle.com/d  /etc/hosts"
    Puppet.debug("mos_cmd=#{mos_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(mos_cmd, :failonfail => true)
        Puppet.debug("MOS details removed sccessfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("MOS details removal error: #{e.message}, output: #{command_output}")
        raise e
    end

    #Remove Repository settings
    sudoers_cmd = "sed -i '/#{os_user}   ALL=(ALL)       NOPASSWD: ALL/d' /etc/sudoers"
    Puppet.debug("sudoers_cmd=#{sudoers_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(sudoers_cmd, :failonfail => true)
        Puppet.debug("Sudoers list updated successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("Sudoers list updation error: #{e.message}, output: #{command_output}")
        raise e
    end
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



  def configure_pet  

    Puppet.debug("PET configuration started")
    deploy_user       = resource[:deploy_user]
    deploy_user_group = resource[:deploy_user_group]
    ps_home_dir       = resource[:ps_home_dir]
    ps_app_home_dir   = resource[:ps_app_home_dir]

    ca_dir = File.join("#{ps_home_dir}", 'openssl', 'CA')
    FileUtils.mkdir_p(ca_dir) unless File.exists?(ca_dir)
    FileUtils.chown_R(deploy_user, deploy_user_group, ca_dir)
    FileUtils.chmod(0755, ca_dir)

    setupca_dir = File.join("#{ps_app_home_dir}", 'cloud_setup', 'scripts')
    pet_command = "su - #{deploy_user} -c \"cd #{setupca_dir} && sh setupca.sh #{ca_dir}\""
    Puppet.debug("PET command: #{pet_command}")

    begin
        command_output = Puppet::Util::Execution.execute(pet_command, :failonfail => true)
        Puppet.debug("PET configured successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("PET configuration failed: #{e.message}, output: #{command_output}")
        raise e
    end

    openssl_conf_cmd = "echo \"export OPENSSL_CONF=#{ps_home_dir}/openssl/CA/openssl.cnf\" >> /etc/profile"
    openssl_conf_bashrc_cmd = "echo \"export OPENSSL_CONF=#{ps_home_dir}/openssl/CA/openssl.cnf\" >> /etc/bashrc"
    Puppet.debug("openssl_conf_cmd=#{openssl_conf_cmd}")
    Puppet.debug("openssl_conf_bashrc_cmd=#{openssl_conf_bashrc_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(openssl_conf_cmd, :failonfail => true)
	command_output = Puppet::Util::Execution.execute(openssl_conf_bashrc_cmd, :failonfail => true)
        Puppet.debug("OPEN SSL configuration updated successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("Open Ssl configuration updation error: #{e.message}, output: #{command_output}")
        raise e
    end

    Puppet.debug("PET configuration finished")
  end

  def setup_python

    Puppet.debug("Python configuration started")

    os_user           = resource[:os_user]
    ps_app_home_dir   = resource[:ps_app_home_dir]
    dpk_location      = resource[:ps_dpk_location]


    lnx_python_dir = File.join(dpk_location, 'lnx_python')
    win_python_dir = File.join(dpk_location, 'win_python')
    python_dest_path = File.join("#{ps_app_home_dir}", 'cloud')
    python_dest_path_stat = File.stat(python_dest_path)
    Puppet.debug("Pyton bits copying from #{lnx_python_dir} to #{python_dest_path}")
    FileUtils.cp_r(lnx_python_dir, python_dest_path)
    lnx_dest_path = File.join(python_dest_path, 'lnx_python')
    FileUtils.chmod_R(0755, lnx_dest_path)
    FileUtils.chown_R(python_dest_path_stat.uid, python_dest_path_stat.gid, lnx_dest_path)    

    Puppet.debug("Pyton bits copying from #{win_python_dir} to #{python_dest_path}")
    FileUtils.cp_r(win_python_dir, python_dest_path)
    win_dest_path = File.join(python_dest_path, 'win_python')
    FileUtils.chmod_R(0755, win_dest_path)
    FileUtils.chown_R(python_dest_path_stat.uid, python_dest_path_stat.gid, win_dest_path)
 
    Puppet.debug("Python configuration completed")
  end

  def setup_env_variables
    Puppet.debug("Setup environment variables")
    os_user           = resource[:os_user]
    ps_app_home_dir   = resource[:ps_app_home_dir]
    dpk_location      = resource[:ps_dpk_location]

    python_conf_cmd = "echo \"CLOUD_ADMIN_LNX_PYTHON=#{ps_app_home_dir}/cloud\" >> /etc/profile && echo 'export PATH=$CLOUD_ADMIN_LNX_PYTHON:$PATH' >> /etc/profile"
    pythonpath_set_cmd = "echo \"export PYTHONPATH=#{ps_app_home_dir}/cloud\" >> /etc/profile"
    pythonpath_set_bashrc_cmd = "echo \"export PYTHONPATH=#{ps_app_home_dir}/cloud\" >> /etc/bashrc"
    pythonhome_set_cmd = "echo \"export PYTHONHOME=#{ps_app_home_dir}/cloud/lnx_python\" >> /etc/profile"
    pythonhome_set_bashrc_cmd = "echo \"export PYTHONHOME=#{ps_app_home_dir}/cloud/lnx_python\" >> /etc/bashrc"

    Puppet.debug("python_conf_cmd=#{python_conf_cmd}")
    Puppet.debug("pythonpath_set_cmd=#{pythonpath_set_cmd}")
    Puppet.debug("pythonpath_set_bashrc_cmd=#{pythonpath_set_bashrc_cmd}")
    Puppet.debug("pythonhome_set_cmd=#{pythonhome_set_cmd}")
    Puppet.debug("pythonhome_set_bashrc_cmd=#{pythonhome_set_bashrc_cmd}")
	
    begin
        command_output = Puppet::Util::Execution.execute(python_conf_cmd, :failonfail => true)
        command_output = Puppet::Util::Execution.execute(pythonpath_set_cmd, :failonfail => true)
        command_output = Puppet::Util::Execution.execute(pythonpath_set_bashrc_cmd, :failonfail => true)
	command_output = Puppet::Util::Execution.execute(pythonhome_set_cmd, :failonfail => true)
        command_output = Puppet::Util::Execution.execute(pythonhome_set_bashrc_cmd, :failonfail => true)
        Puppet.debug("CM specific environment variables updated successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("CM specific environment variables updation error: #{e.message}, output: #{command_output}")
        raise e
    end

    Puppet.debug("Environment variable setup completed")

  end

  def setup_cm_repository

    Puppet.debug("Repository settings started")

    os_user           = resource[:os_user]
    sudoers_cmd = "echo \"#{os_user}   ALL=(ALL)       NOPASSWD: ALL\" >> /etc/sudoers"
    Puppet.debug("sudoers_cmd=#{sudoers_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(sudoers_cmd, :failonfail => true)
        Puppet.debug("Sudoers list updated successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("Sudoers list updation error: #{e.message}, output: #{command_output}")
        raise e
    end

    mos_details_cmd = "echo -e \"141.146.44.51    updates.oracle.com\n209.17.4.8   login.oracle.com\" >>  /etc/hosts" 
    Puppet.debug("mos_details_cmd=#{mos_details_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(mos_details_cmd, :failonfail => true)
        Puppet.debug("MOS details updated successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("MOS details updation error: #{e.message}, output: #{command_output}")
        raise e
    end

    sudoers_cmd = 'sed -i -e \'s|\(^Defaults[ \t]*requiretty\)|#\1|g\' -e \'s|\(^Defaults[ \t]*!visiblepw\)|#\1|g\'  /etc/sudoers '
    Puppet.debug("sudoers_cmd=#{sudoers_cmd}")
    begin
        command_output = Puppet::Util::Execution.execute(sudoers_cmd, :failonfail => true)
        Puppet.debug("Repository chanel details updated successfully")
    rescue Puppet::ExecutionFailure => e
        Puppet.debug("Repository chanel  updation error: #{e.message}, output: #{command_output}")
        raise e
    end
    Puppet.debug("Repository setting completed")

  end
end
