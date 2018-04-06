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

require 'easy_type'
require 'tempfile'
require 'fileutils'

require 'pt_comp_utils/validations'

Puppet::Type.type(:pt_compile_cobol).provide :compile_cobol do
  include EasyType::Template
  include ::PtCompUtils::Validations

  desc "The compile COBOL provider compiles cobol sources in PS_HOME
       and PS_APP_HOME if specified."

  mk_resource_methods

  def self.instances
    []
  end

  def compile_cobol
    Puppet.debug("Action catalog called")

    if Facter.value(:osfamily) != 'windows'
      # make sure the given users exists
      ps_home_user = resource[:ps_home_owner]
      if ps_home_user.nil? == false and
         os_user_exists?(ps_home_user) == false
        fail("ps_home_owner #{ps_home_user} does not exists")
      end
      ps_app_home_user = resource[:ps_app_home_owner]
      if ps_app_home_user.nil? == false and
         os_user_exists?(ps_app_home_user) == false
        fail("ps_app_home_owner #{ps_app_home_user} does not exists")
      end
      ps_cust_home_user = resource[:ps_cust_home_owner]
      if ps_cust_home_user.nil? == false and
         os_user_exists?(ps_cust_home_user) == false
        fail("ps_cust_home_owner #{ps_cust_home_user} does not exists")
      end
    end

    # validate to make sure the homes exists
    ps_home_dir = resource[:ps_home_dir]
    unless FileTest.directory?(ps_home_dir)
      fail("PS_HOME directory #{ps_home_dir} does not exists")
    end
    cobol_home_dir = resource[:cobol_home_dir]
    unless FileTest.directory?(cobol_home_dir)
      fail("Cobol install directory #{cobol_home_dir} does not exists")
    end
    ps_app_home_dir = resource[:ps_app_home_dir]
    if ps_app_home_dir.nil? == false
      unless FileTest.directory?(ps_app_home_dir)
        fail("PS_APP_HOME directory #{ps_app_home_dir} does not exists")
      end
    end
    ps_cust_home_dir = resource[:ps_cust_home_dir]
    if ps_cust_home_dir.nil? == false
      unless FileTest.directory?(ps_cust_home_dir)
        fail("PS_CUST_HOME directory #{ps_cust_home_dir} does not exists")
      end
    end

    ps_home_dir = resource[:ps_home_dir]
    ps_app_home_dir = resource[:ps_app_home_dir]
    ps_cust_home_dir = resource[:ps_cust_home_dir]
    if Facter.value(:osfamily) == 'windows'

      # setup the environment variables first
      ENV['PS_HOME'] = ps_home_dir
      ENV['COBROOT'] = cobol_home_dir
      if ps_app_home_dir.nil? == false
        ENV['PS_APP_HOME'] = ps_app_home_dir
      end
      if ps_cust_home_dir.nil? == false
        ENV['PS_CUST_HOME'] = ps_cust_home_dir
      end
      temp_dir_name = Dir.tmpdir()
      drive_letter = ps_home_dir.match(/^([a-zA-Z]):/)[0]

      compile_cmd = "cd #{ps_home_dir}/setup && cblbld #{drive_letter} #{temp_dir_name}"
    else
      compile_cmd = "#{ps_home_dir}/setup/pscbl.mak"
    end

    # first compile the cobol sources from PS_HOME
    Puppet.debug("Compiling PS_HOME cobol sources")
    if Facter.value(:osfamily) == 'windows'
      compile_pshome_cmd = "#{compile_cmd} ps_home"
    else
      if Facter.value(:osfamily) == 'Solaris' or Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
           compile_pshome_cmd = "su - #{ps_home_user} -c \"#{compile_cmd} ps_home\""
      else 
           compile_pshome_cmd = "su -s /bin/bash - #{ps_home_user} -c \"#{compile_cmd} ps_home\""
      end
    end
    begin
      Puppet.debug("PS_HOME cobol compile command: #{compile_pshome_cmd}")

      command_output = Puppet::Util::Execution.execute(compile_pshome_cmd, :failonfail => true)
      Puppet.debug("PS_HOME cobol compiled successfully: #{command_output}")

    rescue Puppet::ExecutionFailure => e
    	raise Puppet::ExecutionFailure, "PS_HOME cobol execution failed: #{e.message}"
    end

    # compile the cobol sources from PS_APP_HOME
    if ps_app_home_dir.nil? == false
      custom_compile_cmd = File.join(ps_app_home_dir, 'setup', 'pscblcs.mak')
      Puppet.debug("Compiling PS_APP_HOME cobol sources")

      if Facter.value(:osfamily) == 'windows'
        compile_apphome_cmd = "#{compile_cmd} ps_app_home"
      else
        if File.file?(custom_compile_cmd) == true
          if Facter.value(:osfamily) == 'Solaris' or Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
               compile_apphome_cmd = "su - #{ps_app_home_user} -c \"#{custom_compile_cmd} ps_app_home\""
          else 
               compile_apphome_cmd = "su -s /bin/bash - #{ps_app_home_user} -c \"#{custom_compile_cmd} ps_app_home\""
          end
        else
          if Facter.value(:osfamily) == 'Solaris' or Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
               compile_apphome_cmd = "su - #{ps_app_home_user} -c \"#{compile_cmd} ps_app_home\""
          else
               compile_apphome_cmd = "su -s /bin/bash - #{ps_app_home_user} -c \"#{compile_cmd} ps_app_home\""
          end 
        end
      end
      begin
        Puppet.debug("PS_APP_HOME cobol compile command: #{compile_apphome_cmd}")

        command_output = Puppet::Util::Execution.execute(compile_apphome_cmd, :failonfail => true)
        Puppet.debug("PS_APP_HOME cobol compiled successfully: #{command_output}")

      rescue Puppet::ExecutionFailure => e
    	  raise Puppet::ExecutionFailure, "PS_APP_HOME cobol execution failed: #{e.message}"
      end
    end

    # compile the cobol sources from PS_CUST_HOME
    if ps_cust_home_dir.nil? == false
      Puppet.debug("Compiling PS_CUST_HOME cobol sources")
      if Facter.value(:osfamily) == 'windows'
        compile_custhome_cmd = "#{compile_cmd} ps_cust_home"
      else
        if Facter.value(:osfamily) == 'Solaris' or Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
             compile_custhome_cmd = "su - #{ps_cust_home_user} -c \"#{compile_cmd} ps_cust_home\""
        else
             compile_custhome_cmd = "su -s /bin/bash - #{ps_cust_home_user} -c \"#{compile_cmd} ps_cust_home\""
        end
      end
      begin
        Puppet.debug("PS_CUST_HOME cobol compile command: #{compile_custhome_cmd}")

        command_output = Puppet::Util::Execution.execute(compile_custhome_cmd, :failonfail => true)
        Puppet.debug("PS_CUST_HOME cobol compiled successfully: #{command_output}")

      rescue Puppet::ExecutionFailure => e
    	  raise Puppet::ExecutionFailure, "PS_CUST_HOME cobol execution failed: #{e.message}"
      end
    end

    # link the cobol sources on unix platform
    if Facter.value(:osfamily) != 'windows'
      Puppet.debug("Linking cobol sources")
      if Facter.value(:osfamily) == 'Solaris' or Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
          cobol_link_cmd = "su - #{ps_home_user} -c \"#{ps_home_dir}/setup/psrun.mak\""
      else
          cobol_link_cmd = "su -s /bin/bash - #{ps_home_user} -c \"#{ps_home_dir}/setup/psrun.mak\""
      end

      begin
        command_output = Puppet.debug("Cobol link command: #{cobol_link_cmd}")

        Puppet::Util::Execution.execute(cobol_link_cmd, :failonfail => true)
        Puppet.debug("Cobol sources linked successfully: #{command_output}")

      rescue Puppet::ExecutionFailure => e
    	  raise Puppet::ExecutionFailure, "Cobol sources linking failed: #{e.message}"
      end
    end
  end
end
