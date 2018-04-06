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

require 'tempfile'
require 'tmpdir'
require 'etc'
require 'pt_comp_utils/database'
require 'puppet/provider/pt_data_mover/data_mover'

Puppet::Type.type(:pt_password).provide :password, :parent => Puppet::Provider::Datamover do
  include ::PtCompUtils::Database

  mk_resource_methods

  def change_psft_passwords()
    pia_domain_number = resource[:pia_domain_number]
    # Set the Access Password
    db_access_pwd = resource[:db_access_pwd]

    db_access_id = change_db_access_pwd
    if pia_domain_number <= 1
      log_loc = create_dms_log_file
      dms_content_array = Array.new
      dms_content_array << "set log #{log_loc}; "
      dms_content_array << "CHANGE_ACCESS_PASSWORD SYSADM1 " + db_access_pwd

      dms_location = create_dms_script(dms_content_array)
      output, status = run_dms_script(dms_location, db_access_id)
      Puppet.debug('Output of the executed DMS: ' + output.gsub(db_access_pwd, '****'))
      dms_run_log = File.read(log_loc)

      if status == 0 and (dms_run_log.include?'Successful completion' and !dms_run_log.include?'Unsuccessful completion')
        Puppet.notice "successfully changed the DB Access password for #{db_access_id}"
      else
        fail("Could not change the DB Access - #{db_access_id} Password. DMS has Failed")
      end
      FileUtils.remove_file(log_loc, :force => true)
    end

    # Set the Web profile Password
    if pia_domain_number != 0
      pia_site_list = resource[:pia_site_list]
      profile_user = ''
      profile_user_pwd = ''
      pia_site_list.each do |pia_site|
        pia_site = pia_site[4..-2]
        pia_site.split(", ").each do |pia_site_info|
          if pia_site_info.start_with?('"webprofile_settings=')
            pia_site_info.split('=', 2)[1].chomp('"').strip.split(',').each do |webprofile_info|
              if webprofile_info.start_with?('profile_user=')
                profile_user = webprofile_info.split('=')[1]
              elsif webprofile_info.start_with?('profile_user_pwd=')
                profile_user_pwd = webprofile_info.split('=')[1]
              end
            end
          end
        end
        if profile_user.nil? || profile_user.empty?
          profile_user = 'PTWEBSERVER'
        end
        if profile_user_pwd == '<WEBPROFILE_USER_PWD>'
          Puppet.debug("There is no Web Profile password provided to change")
        else
          log_loc = create_dms_log_file
          dms_content_array = Array.new
          dms_content_array << "set log #{log_loc}; "
          dms_content_array << "UPDATE PSOPRDEFN SET PTOPERPSWDV2 = '#{profile_user_pwd}', ENCRYPTED = 0 WHERE OPRID = '#{profile_user}';"
          dms_content_array << "ENCRYPT_PASSWORD #{profile_user}"

          dms_location = create_dms_script(dms_content_array)
          output, status = run_dms_script(dms_location, db_access_id)
          Puppet.debug('Output of the executed DMS: ' + output.gsub(profile_user_pwd, '****'))
          dms_run_log = File.read(log_loc)

          if status == 0 and (dms_run_log.include?'Successful completion' and !dms_run_log.include?'Unsuccessful completion')
            Puppet.notice "successfully changed the Web Profile password for #{profile_user}"
          else
            fail("Could not change the Web Profile - #{profile_user} Password. DMS has Failed")
          end
          FileUtils.remove_file(log_loc, :force => true)
        end
      end
    else
      Puppet.debug("There is no site list provided to change the passwords")
    end

    if pia_domain_number <= 1
      # Set Opr Passoword
      db_opr_id = resource[:db_opr_id]
      db_opr_pwd = resource[:db_opr_pwd]
      log_loc = create_dms_log_file
      dms_content_array = Array.new
      dms_content_array << "set log #{log_loc}; "
      dms_content_array << "UPDATE PSOPRDEFN SET PTOPERPSWDV2 = '#{db_opr_pwd}', ENCRYPTED = 0 WHERE OPRID = '#{db_opr_id}';"
      dms_content_array << "ENCRYPT_PASSWORD #{db_opr_id}"

      dms_location = create_dms_script(dms_content_array)
      output, status = run_dms_script(dms_location, db_access_id)
      Puppet.debug('Output of the executed DMS: ' + output.gsub(db_opr_pwd, '****'))
      dms_run_log = File.read(log_loc)
      if status == 0 and (dms_run_log.include?'Successful completion' and !dms_run_log.include?'Unsuccessful completion')
        Puppet.notice "successfully changed the password for the Oper ID - #{db_opr_id}"
      else
        fail("Could not change the Oper ID - #{db_opr_id} Password. DMS has Failed")
      end
      FileUtils.remove_file(log_loc, :force => true)
    end
  end

  def change_db_access_pwd()
      oracle_home_dir = resource[:oracle_client_home]
      oracle_user = resource[:os_user]
      temp_dir_name = Dir.tmpdir
      database_name = resource[:db_name]
      db_admin_pwd  = resource[:db_admin_pwd]
	    db_access_pwd = resource[:db_access_pwd]

      # get the access id
      rand_num = rand(1000)
      access_sql_path = File.join(temp_dir_name, "access-#{rand_num}.sql")
      access_sql = File.open(access_sql_path, 'w')
      access_sql.puts("SET HEADING OFF;")
      access_sql.puts("SET FEEDBACK OFF;")
      access_sql.puts("ALTER SESSION SET CONTAINER = #{database_name};")
      access_sql.puts("SELECT OWNERID FROM PS.PSDBOWNER;")
      access_sql.close
      File.chmod(0755, access_sql_path)
      Puppet.debug(File.read(access_sql_path))

      sql_output = execute_pdb_sql_command_file(oracle_home_dir, database_name, access_sql_path, oracle_user, db_admin_pwd)
      if sql_output.include?('ERROR')
        fail("Error getting access id from the database: #{database_name}")
      end
      access_id = sql_output.strip
      Puppet.debug("Access id of the database: #{access_id}")
      FileUtils.remove_file(access_sql_path, :force => true)

	    sql_path = File.join(temp_dir_name, "access-change-#{rand_num}.sql")
      sql_qry = File.open(sql_path, 'w')

      sql_qry.puts("SET HEADING OFF;")
      sql_qry.puts("SET FEEDBACK OFF;")
      sql_qry.puts("ALTER SESSION SET CONTAINER = #{database_name};")
      sql_qry.puts("ALTER USER #{access_id} IDENTIFIED BY \"#{db_access_pwd}\";")
      sql_qry.close
      File.chmod(0755, sql_path)
      sql_output = execute_pdb_sql_command_file(oracle_home_dir, database_name, sql_path, oracle_user, db_admin_pwd)
      Puppet.debug("Output of the Query to change Password: \n" + sql_output.gsub(db_access_pwd, '****'))
      if sql_output.downcase.include?('error')
        fail("Error While Running Qry to change the Access Password for the DB : #{database_name}")
      else
        Puppet.notice "successfully altered the user password for #{access_id} in DB "
      end
      FileUtils.remove_file(sql_path, :force => true)
      return access_id
  end
  def create_dms_log_file()
    # genenrate the DMS file
    temp_dir_name = Dir.tmpdir
    rand_num = rand(1000)
    file_path = File.join(temp_dir_name, "temp_dms_#{rand_num}.log")
    file_prop = File.new(file_path, 'w')
    file_prop.close
    File.chmod(0777, file_path)
    if Facter.value(:osfamily) == 'windows'
      file_path = file_path.gsub('/','\\')
    end
    return file_path
  end
end
