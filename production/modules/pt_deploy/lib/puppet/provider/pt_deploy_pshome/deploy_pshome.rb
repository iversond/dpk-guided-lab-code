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

Puppet::Type.type(:pt_deploy_pshome).provide :deploy_pshome,
                  :parent => Puppet::Provider::DeployArchive do

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
  # 1. Need to check what facter returns for osfamily, on an HP system  sep 09/30/2016
  # 2. Need to check if unzip is avaiable on HP                         sep 09/30/2016 
  #
  if Facter.value(:osfamily) == 'HP-UX'
    commands :extract_cmd =>  'tar'
    commands :unzip_cmd   =>  'unzip'
  end

  mk_resource_methods

  private

  def pre_create()
    db_platform = resource[:db_type].to_s
    db_platform = db_platform.upcase

    if db_platform != 'ORACLE' and db_platform != 'DB2ODBC' and db_platform != 'DB2UNIX' and db_platform != 'MSSQL'
      raise ArgumentError, "DB Platform #{db_platform} is not supported in this release"
    end
    super()
  end

  def post_create()
    extract_only = resource[:extract_only]
    if extract_only == true
      Puppet.debug("PS Home will not be modified since extract_only flag is set to true")
      return
    end
    # setup PS_HOME for database type
    db_platform = resource[:db_type].to_s
    db_platform = db_platform.upcase

    if db_platform == 'ORACLE'
      db_type = 'ORA'
    elsif db_platform == 'DB2ODBC'
      db_type = 'DB2'
    elsif db_platform == 'DB2UNIX'
      db_type = 'DBX'
    elsif db_platform == 'MSSQL'
      db_type = 'MSS'
    else
      cleanup_installation()
      raise ArgumentError, "DB Platform #{db_platform} is not supported in this release"
    end

    begin
      # setup PS HOME for database type
      ps_home = resource[:deploy_location]
      Puppet.debug("Setting up #{ps_home} for database type #{db_platform}")

      FileUtils.mv(File.join(ps_home, db_type, 'sqr'), ps_home)
      FileUtils.mv(File.join(ps_home, db_type, 'bin', 'sqr'),
                   File.join(ps_home, 'bin'))
      FileUtils.mv(File.join(ps_home, db_type, 'scripts'), ps_home)

      if Facter.value(:osfamily) == 'windows'
        FileUtils.mv(File.join(ps_home, db_type, 'setup', 'PsMpDbInstall'), File.join(ps_home, 'setup'))
        FileUtils.mv(File.join(ps_home, db_type, 'setup', 'pstools.cfg'), File.join(ps_home, 'setup'))
       
        if db_type == 'DB2'
          ps_home_norm = ps_home.gsub('\\', '/')
          zos_dir = Dir.glob(File.join(ps_home_norm, db_type, 'bin', 'server', 'zos-*-zarch'))[0]
          FileUtils.mv(zos_dir, File.join(ps_home, 'bin', 'server'))
          FileUtils.mv(File.join(ps_home, db_type, 'bin', 'psprocinfo'),
                       File.join(ps_home, 'bin'))
        end
      else
          FileUtils.mv(File.join(ps_home, db_type, 'setup', 'psdb.sh'), File.join(ps_home, 'setup'))
          FileUtils.mv(File.join(ps_home, db_type, 'psconfig.sh'), ps_home)
      end
      dbcodes_file = File.join(ps_home, db_type, 'setup', 'dbcodes.pt')
      FileUtils.mv(dbcodes_file, File.join(ps_home, 'setup'))
	  
      FileUtils.mv(File.join(ps_home, db_type, 'peopletools.properties'), ps_home)

      #remove the database directories from ps home
      FileUtils.remove_dir(File.join(ps_home, 'ORA'), true)
      FileUtils.remove_dir(File.join(ps_home, 'DBX'), true)
      FileUtils.remove_dir(File.join(ps_home, 'DB2'), true)

      if Facter.value(:osfamily) == 'windows'
        FileUtils.remove_dir(File.join(ps_home, 'MSS'), true)
      end
	  
      #update the license in dbcodes.pt	  
      if db_platform == 'ORACLE'
        linenumber = 3
      elsif db_platform == 'DB2ODBC'
        linenumber = 1
      elsif db_platform == 'DB2UNIX'
        linenumber = 4
      elsif db_platform == 'MSSQL'
        linenumber = 2
	  end
	  	  
      dbcodescfg_file = File.join(ps_home, 'setup', 'dbcodecfg.txt')
      s = read_line_number(dbcodescfg_file, linenumber)
	  licensenum =  s.split('=')[1].strip
      licensecode = "LICENSE_CODE = " + licensenum
      licensegroup = "LICENSE_GROUP = 06"
      dbcodeslic_file = File.join(ps_home, 'setup', 'dbcodes.pt')
      db_codes = File.read(dbcodeslic_file)
      db_codes = db_codes.gsub(/LICENSE_GROUP =/, licensegroup)
      db_codes = db_codes.gsub(/LICENSE_CODE =/, licensecode)
      File.open(dbcodeslic_file, "w") { |file| file << db_codes }

      # check ifunicode is requested
      unicode_db = resource[:unicode_db]
      if unicode_db == true
      # copy the files 
        if db_platform == 'DB2ODBC'
           if Facter.value(:osfamily) == 'windows'
              # copy files from /src/cbl/mvs/unicode to /src/cbl/mvs
              FileUtils.cp_r(File.join(ps_home, 'src', 'cbl', 'mvs', 'unicode') + '/.', File.join(ps_home, 'src', 'cbl', 'mvs'))
		   
              # edit the file /src/cbl/mvs/psbndsql.jcl 		   
              cbl_file_path = File.join(ps_home, 'src', 'cbl', 'mvs','PSBNDSQR.JCL')
              encodeupdate = "ENCODING(UNICODE) - "
              cbl_file = File.read(cbl_file_path)
              cbl_file = cbl_file.gsub(/%ENCODING%/, encodeupdate) 
              File.open(cbl_file_path, "w") { |file| file << cbl_file}
           
		   
              #pshome\sqr\PSSQRINI.OS390 - search for `;ENCODING-DATABASE-API=UCS2¿ and  remove the semicolon 
              sqr_file_path = File.join(ps_home, 'sqr', 'PSSQRINI.OS390')
              sqrupdate = "ENCODING-DATABASE-API=UCS2"
              sqr_file = File.read(sqr_file_path)
              sqr_file = sqr_file.gsub(/;ENCODING-DATABASE-API=UCS2/, sqrupdate) 
              File.open(sqr_file_path, "w") { |file| file << sqr_file}
		    
              #pshome\sqr\PSSQRJPN.OS390 - search for `;ENCODING-DATABASE-API=UCS2¿ and  remove the semicolon
              sqr_file_path = File.join(ps_home, 'sqr', 'PSSQRJPN.OS390')
              sqrupdate = "ENCODING-DATABASE-API=UCS2"
              sqr_file = File.read(sqr_file_path)
              sqr_file = sqr_file.gsub(/;ENCODING-DATABASE-API=UCS2/, sqrupdate) 
              File.open(sqr_file_path, "w") { |file| file << sqr_file}
		   
              #pshome\sqr\PSSQRKOR.OS390 - search for `;ENCODING-DATABASE-API=UCS2¿ and  remove the semicolon
              sqr_file_path = File.join(ps_home, 'sqr', 'PSSQRKOR.OS390')
              sqrupdate = "ENCODING-DATABASE-API=UCS2"
              sqr_file = File.read(sqr_file_path)
              sqr_file = sqr_file.gsub(/;ENCODING-DATABASE-API=UCS2/, sqrupdate) 
              File.open(sqr_file_path, "w") { |file| file << sqr_file}
		   
              #pshome\sqr\PSSQRZHS.OS390 - search for `;ENCODING-DATABASE-API=UCS2¿ and  remove the semicolon
              sqr_file_path = File.join(ps_home, 'sqr', 'PSSQRZHS.OS390')
              sqrupdate = "ENCODING-DATABASE-API=UCS2"
              sqr_file = File.read(sqr_file_path)
              sqr_file = sqr_file.gsub(/;ENCODING-DATABASE-API=UCS2/, sqrupdate) 
              File.open(sqr_file_path, "w") { |file| file << sqr_file}
		   
              #pshome\sqr\PSSQRZHT.OS390 - search for `;ENCODING-DATABASE-API=UCS2¿ and  remove the semicolon
              sqr_file_path = File.join(ps_home, 'sqr', 'PSSQRZHT.OS390')
              sqrupdate = "ENCODING-DATABASE-API=UCS2"
              sqr_file = File.read(sqr_file_path)
              sqr_file = sqr_file.gsub(/;ENCODING-DATABASE-API=UCS2/, sqrupdate) 
              File.open(sqr_file_path, "w") { |file| file << sqr_file}
           end  
        end
      end

      if unicode_db == false
        Puppet.debug("Updating PS_HOME for Non-Unicode database")
        # remove the folder 
        if db_platform == 'DB2ODBC'
           if Facter.value(:osfamily) == 'windows'
              FileUtils.remove_dir(File.join(ps_home, 'src', 'cbl', 'mvs', 'unicode'), true)
              # edit the file /src/cbl/mvs/psbndsql.jcl 		   
              cbl_file_path = File.join(ps_home, 'src', 'cbl', 'mvs','PSBNDSQR.JCL')
              encodeupdate = "ENCODING(EBCDIC) -"
                cbl_file = File.read(cbl_file_path)
              cbl_file = cbl_file.gsub(/%ENCODING%/, encodeupdate) 
              File.open(cbl_file_path, "w") { |file| file << cbl_file}		
           end 			  
        end
		
        # remove the unicode.cfg file
        FileUtils.rm_rf(File.join(ps_home, 'setup', 'unicode.cfg'))

        # update the unicode value in peopletools.properties file
        pt_prop_file = File.join(ps_home, 'peopletools.properties')
        pt_props = File.read(pt_prop_file)
        pt_props = pt_props.gsub(/unicodedb=1/, 'unicodedb=0')
        File.open(pt_prop_file, "w") { |file| file << pt_props }
      end
    rescue Exception => e
      cleanup_installation()
      raise e
    end
    # install patches if specified
    patch_list = resource[:patch_list]
    if ! patch_list.nil?
      patch_list = [patch_list] unless patch_list.is_a? Array
      patch_list.each do |patch|
        Puppet.debug("Installing patch: #{patch} into #{ps_home}")
        if Facter.value(:osfamily) == 'windows'
          Puppet.debug(" Installing on Windows platform")
          extract_zip_script = generate_windows_unzip_script(patch, ps_home)
          system("powershell -File #{extract_zip_script}")
          if $? == 0
            Puppet.debug("Installation of tools patch #{patch} successful")
          else
            raise Puppet::ExecutionFailure, "Installation of tools patch #{patch} failed"
          end
        else
          deploy_user = resource[:deploy_user]
          deploy_group = resource[:deploy_user_group]

          Puppet.debug(" Installing on Non Windows platform")
          begin
            if Facter.value(:kernel) == 'AIX'
              system("cd #{ps_home} && gunzip -r #{patch} -c | tar xf -")
            else
              unzip_cmd('-d', ps_home, patch)
            end
            change_ownership(deploy_user, deploy_group, ps_home)

          rescue Puppet::ExecutionFailure => e
            raise Puppet::Error, "Installation of tools patch #{patch} failed: #{e.message}"
          end
        end
      end
    else
      Puppet.debug("No Tools Patches specified")
    end
    # install the visual studo dll for Windows
    if Facter.value(:osfamily) == 'windows'
      # FileUtils.chmod_R(0755, deploy_location)
      # give full control to 'Administrators'
      #  TODO: need to check why the chmod_R is not working
      #perm_cmd = "icacls #{ps_home} /grant Administrators:(OI)(CI)F /T > NUL"
      perm_cmd = "icacls #{ps_home} /grant *S-1-5-32-544:(OI)(CI)F /T > NUL"
      system(perm_cmd)
      if $? == 0
        Puppet.debug('PS_HOME deploy location permissions updated successfully')
      else
        cleanup_installation()
        raise Puppet::ExecutionFailure, "JDK deploy location permissions update failed"
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
      #Puppet.debug('Visual Studio DLL (64-bit) uninstalled successfully')

    end
    super()
  end

  def cleanup_installation()
    deploy_location = resource[:deploy_location]

    begin
      # remove the install directory
      FileUtils.rm_rf(deploy_location)
    rescue
      Puppet.debug("Cleanup of PS_HOME installation failed.")
    end
  end
end

def read_line_number(filename, number)
  return nil if number < 1
  line = File.readlines(filename)[number-1]
  line ? line.chomp : nil
end