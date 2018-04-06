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
require 'open3'

Puppet::Type.type(:pt_deploy_apphome).provide :deploy_apphome,
                  :parent => Puppet::Provider::DeployArchive do

  #if Facter.value(:osfamily) == 'RedHat'
   # commands :extract_cmd =>  'tar'
    #commands :unzip_cmd   =>  'unzip'
     #         end
  #if Facter.value(:osfamily) == 'AIX'
    #commands :extract_cmd  =>  'gunzip'
  #end
    
  if Facter.value(:osfamily) == 'RedHat'
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end
  if Facter.value(:osfamily) == 'AIX'
    commands :extract_cmd  =>  'gunzip'
    commands :unzip_cmd   =>  'unzip'
  end

  if (Facter.value(:kernel) == 'Solaris') || (Facter.value(:osfamily) == 'Solaris')
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end

  mk_resource_methods

  private

  def pre_create()
    db_platform = resource[:db_type].to_s
    db_platform = db_platform.upcase

    if db_platform != 'ORACLE' and db_platform != 'DB2ODBC' and db_platform != 'DB2UNIX'and db_platform != 'MSSQL'
      raise ArgumentError, "DB Platform #{db_platform} is not supported in this release"
    end
    super()
  end

  def post_create()
    extract_only = resource[:extract_only]
    if extract_only == true
      Puppet.debug("PS APP Home will not be modified since extract_only flag is set to true")
      return
    end

    # setup PS_HOME for database type
    db_platform = resource[:db_type].to_s
    db_platform = db_platform.upcase

    # setup PS HOME for database type
    ps_home = resource[:deploy_location]

    Puppet.debug("Setting up #{ps_home} for database platform #{db_platform}")

    if db_platform == 'ORACLE'
      db_type = 'ora'
    elsif db_platform == 'DB2ODBC'
      db_type = 'db2'
    elsif db_platform == 'DB2UNIX'
      db_type = 'dbx'
    elsif db_platform == 'MSSQL'
      db_type = 'mss'
    else
      raise ArgumentError "DB Platform #{db_platform} is not supported in this release"
      return
    end
	
    begin	
      if (db_type != 'mss')	
         FileUtils.cp_r(File.join(ps_home, 'scripts', db_type) + "/.", File.join(ps_home,'scripts'))
      end 
	  
      FileUtils.cp_r(File.join(ps_home, 'setup', db_type) + "/.", File.join(ps_home, 'setup'))

      if Facter.value(:osfamily) == 'windows'
        if db_type == 'db2'
          FileUtils.cp_r(File.join(ps_home, 'class', db_type, 'OS390') + "/.",
                      File.join(ps_home, 'class'))
        end
      end
      #remove the database directories from ps home
      FileUtils.remove_dir(File.join(ps_home, 'scripts', 'ora'), true)
      FileUtils.remove_dir(File.join(ps_home, 'scripts', 'dbx'), true)
      FileUtils.remove_dir(File.join(ps_home, 'scripts', 'db2'), true)
	  
      FileUtils.remove_dir(File.join(ps_home, 'setup', 'ora'), true)
      FileUtils.remove_dir(File.join(ps_home, 'setup', 'dbx'), true)
      FileUtils.remove_dir(File.join(ps_home, 'setup', 'db2'), true)
      FileUtils.remove_dir(File.join(ps_home, 'setup', 'mss'), true)
	  
      if Facter.value(:osfamily) == 'windows'	  
        FileUtils.remove_dir(File.join(ps_home, 'class', 'db2', 'OS390'), true)	
        FileUtils.remove_dir(File.join(ps_home, 'class', 'db2'), true)	  
      end
	  
    rescue Exception => e
      FileUtils.rm_rf(ps_home)
      raise e
    end
	
   
    data_dir = File.join(ps_home, 'data')
	
    install_type_opt = resource[:install_type]
    # remove the system db files for PUM installation
    if  install_type_opt == 'PUM'
       FileUtils.rm Dir[data_dir + "/*eng*.db"]
    end 
				
    # if translations.zip file is provided, extract it
    translations_file = resource[:translations_zip_file]
    if ! translations_file.nil?
      Puppet.debug("Installing translations ZIP file #{translations_file} into #{data_dir}")
      if Facter.value(:osfamily) == 'windows'
        Puppet.debug(" Installing on Windows platform")
        extract_zip_script = generate_windows_unzip_script(translations_file, data_dir)
        system("powershell -File #{extract_zip_script}")
        if $? == 0
          Puppet.debug("Installation of translations ZIP file #{translations_file} successful")
        else
          raise Puppet::ExecutionFailure, "Installation of translations ZIP file #{translations_file} failed"
        end
      else
        deploy_user = resource[:deploy_user]
        deploy_group = resource[:deploy_user_group]

        Puppet.debug(" Installing on non Windows platform")
        begin
          #if Facter.value(:kernel) == 'AIX'
            #system("cd #{data_dir} && gunzip -r #{translations_file}")
          #else
          unzip_cmd('-d', data_dir, translations_file)
          #end
          change_ownership(deploy_user, deploy_group, ps_home)

        rescue Puppet::ExecutionFailure => e
          raise Puppet::Error, "Installation of translations ZIP file #{translations_file} failed: #{e.message}"
        end
      end
    end

    # install the visual studo dll for Windows
    if Facter.value(:osfamily) == 'windows'
      #perm_cmd = "icacls #{ps_home} /grant Administrators:(OI)(CI)F /T > NUL"
      perm_cmd = "icacls #{ps_home} /grant *S-1-5-32-544:(OI)(CI)F /T > NUL"
      system(perm_cmd)
      if $? == 0
        Puppet.debug('PS_APP_HOME deploy location permissions updated successfully')
      else
        raise Puppet::ExecutionFailure, "PS_APP_HOME deploy location permissions update failed"
      end
        
      #Remove the old 2015 PS installed CRT - 64bit
      vs_del_cmd = "msiexec /norestart /qn /x {329393B0-AE6F-41BA-BD56-4BE3C018D5B5}"
      #Puppet.debug("Visual Studio DLL Uninstall command: #{vs_del_cmd}")
      Puppet::Util::Execution.execute(vs_del_cmd, :failonfail => false)

      vs_cmd = File.join(ps_home, 'setup', 'psvccrt', 'vcredist_x64.exe')  
      if File.file?(vs_cmd) == false
        vs_cmd = File.join(ps_home, 'setup', 'psvccrt', 'psvccrt_debug_x64.msi')
        vs_cmd = vs_cmd.gsub('/', '\\')
        vs_install_cmd = "msiexec /i #{vs_cmd} /quiet /passive /qn /log #{Dir.tmpdir}\\vsddl_install.log"
      else
        vs_cmd = vs_cmd.gsub('/', '\\')
        vs_install_cmd = "#{vs_cmd} /i /q /norestart /log #{Dir.tmpdir}\\vsddl_install.log" 
      end
       
      Puppet.debug("Visual Studio DLL Install command: #{vs_install_cmd}")
      begin
        Puppet::Util::Execution.execute(vs_install_cmd, :failonfail => true)
        Puppet.debug('Visual Studio DLL(64-bit) installed successfully')
      rescue
        Puppet.debug('Visual Studio DLL(64-bit) installation failed')
      end
    end
  end
 
 def pre_delete()
    # uninstall the visual studo dll for Windows
    if Facter.value(:osfamily) == 'windows'
      ps_home = resource[:deploy_location]

      #Remove the old 2015 PS installed CRT - 64bit
      vs_del_cmd = "msiexec /norestart /qn /x {329393B0-AE6F-41BA-BD56-4BE3C018D5B5}"
      #Puppet.debug("Visual Studio DLL Uninstall command: #{vs_del_cmd}")
      Puppet::Util::Execution.execute(vs_del_cmd, :failonfail => false)
    
    end
    super()
  end
end
