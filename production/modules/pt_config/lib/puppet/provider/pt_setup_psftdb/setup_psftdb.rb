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
require 'open3'
require 'tmpdir'
require 'tempfile'
require 'fileutils'
require 'rexml/document'
require 'pt_comp_utils/validations'
require 'pt_comp_utils/database'
require 'puppet/provider/pt_utils'

if Facter.value(:osfamily) == 'windows'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_setup_psftdb).provide :setup_psftdb do
  include EasyType::Template
  include ::PtCompUtils::Validations
  include ::PtCompUtils::Database

  mk_resource_methods

  @container_hash = {}

  def initialize(value={})
    super(value)
    Puppet.debug("Provider Initialization")
    @property_flush = {}
  end

  def container_hash=(container_hash)
    Puppet.debug("Caching container settings: #{container_hash.inspect}")
    @container_hash = container_hash
  end

  def exists?
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end

    # check to make sure Oracle Home exists
    oracle_home_dir = resource[:oracle_home_dir]
    unless FileTest.directory?(oracle_home_dir)
      return false
    end
    validate_parameters()

    container_name = resource[:container_name]
    container_exists = check_container_exists?(container_name)
    if container_exists == false
      @property_hash[:ensure] = :absent
      Puppet.debug("Resource does not exists")
      return false
    end
    database_name = resource[:database_name]
    database_plugged = check_database_plugged?(container_name, database_name)
    if database_plugged
      @property_hash[:ensure] = :present
      Puppet.debug("Resource exists")
      return true
    else
      @property_hash[:ensure] = :absent
      Puppet.debug("Resource does not exists")
      return false
    end
  end

  def create
    database_name = resource[:database_name]
    Puppet.debug("Create called for database: #{database_name}")

    container_name  = resource[:container_name]
    database_dir    = resource[:database_dir]
    oracle_user     = resource[:oracle_user]
    oracle_home_dir = resource[:oracle_home_dir]

    if check_container_exists?(container_name) == false
      if resource[:new_container] == true
        Puppet.debug("Container database #{container_name} does not exist, " +
                     "Creating it")
        # create container first
        create_container_database(container_name)
      else
        fail("Database container #{container_name} does not exist")
      end
    end
    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end
    # plug the PDB
    temp_dir_name = Dir.tmpdir()
    rand_num = rand(1000)
    pdb_plug_sql_path = File.join(temp_dir_name, "pdbplub-#{rand_num}.sql")
    pdb_plug_sql = File.open(pdb_plug_sql_path, 'w')

    pdb_plug_sql.puts("CREATE PLUGGABLE DATABASE &1 AS CLONE USING '&2' SOURCE_FILE_NAME_CONVERT=NONE NOCOPY STORAGE UNLIMITED TEMPFILE REUSE;")
    pdb_plug_sql.puts("ALTER PLUGGABLE DATABASE &1 OPEN;")
    pdb_plug_sql.puts("ALTER PLUGGABLE DATABASE &1 SAVE STATE;")
    pdb_plug_sql.puts("EXIT;")
    pdb_plug_sql.close
    File.chmod(0755, pdb_plug_sql_path)
    Puppet.debug(File.read(pdb_plug_sql_path))

    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, pdb_plug_sql_path, oracle_user,
                                          database_name, File.join(database_dir, "#{database_name}.xml"))
    if sql_output.include?('ERROR')
      fail("Error plugging database #{database_name}, Error: #{sql_output}")
    end
    # change the ownership
    pdb_db_sql_file = sql_command_file(template('puppet:///modules/pt_config/pt_psft_database/pdb_scripts/dbname.sql', binding))
    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, pdb_db_sql_file, oracle_user, database_name)

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

    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, access_sql_path, oracle_user)
    if sql_output.include?('ERROR')
      fail("Error getting acess id database: #{database_name}")
    end
    access_id = sql_output.strip
    Puppet.debug("Access id of the database: #{access_id}")

    # get the tools release
    rand_num = rand(1000)
    toolsrel_sql_path = File.join(temp_dir_name, "toolsrel-#{rand_num}.sql")
    toolsrel_sql = File.open(toolsrel_sql_path, 'w')
    toolsrel_sql.puts("SET HEADING OFF;")
    toolsrel_sql.puts("SET FEEDBACK OFF;")
    toolsrel_sql.puts("ALTER SESSION SET CONTAINER = #{database_name};")
    toolsrel_sql.puts("SELECT TOOLSREL FROM #{access_id}.PSSTATUS;")
    toolsrel_sql.close
    File.chmod(0755, toolsrel_sql_path)
    Puppet.debug(File.read(toolsrel_sql_path))

    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, toolsrel_sql_path, oracle_user)
    if sql_output.include?('ERROR')
      fail("Error getting tools release for database: #{database_name}")
    end
    tools_release = sql_output.strip
    Puppet.debug("Tools release of the database: #{tools_release}")

    # update the connect information
    #  get the list of db users
    rand_num = rand(1000)
    users_sql_path = File.join(temp_dir_name, "users-#{rand_num}.sql")
    users_sql = File.open(users_sql_path, 'w')
    users_sql.puts("SET HEADING OFF;")
    users_sql.puts("SET FEEDBACK OFF;")
    users_sql.puts("ALTER SESSION SET CONTAINER = #{database_name};")
    users_sql.puts("SELECT USERNAME FROM DBA_USERS;")
    users_sql.close
    File.chmod(0755, users_sql_path)
    Puppet.debug(File.read(users_sql_path))

    db_users = execute_sql_command_file(oracle_home_dir, container_instance_name, users_sql_path, oracle_user)
    if db_users.include?('ERROR')
      fail("Error getting DB users for database: #{database_name}")
    end
    new_connect_id  = resource[:db_connect_id]
    new_connect_pwd = resource[:db_connect_pwd]

    def_connect_id = 'people'
    rand_num = rand(1000)
    connect_sql_path = File.join(temp_dir_name, "connect-#{rand_num}.sql")
    connect_sql = File.open(connect_sql_path, 'w')
    connect_sql.puts("ALTER SESSION SET CONTAINER = #{database_name};")

    if db_users.upcase.include?(def_connect_id.upcase)
      Puppet.debug("Default connect id #{def_connect_id} exists, dropping that user")
      connect_sql.puts("DROP USER people CASCADE;")
    end
    if db_users.upcase.include?(new_connect_id.upcase) && new_connect_id.upcase != def_connect_id.upcase
      Puppet.debug("Connect id #{new_connect_id} exists, dropping that user")
      connect_sql.puts("DROP USER #{new_connect_id} CASCADE;")
    end
    connect_sql.puts("CREATE USER #{new_connect_id} identified by \"#{new_connect_pwd}\" DEFAULT TABLESPACE PSDEFAULT TEMPORARY TABLESPACE PSTEMP;")
    connect_sql.puts("GRANT CREATE SESSION TO #{new_connect_id};")
    connect_sql.puts("GRANT SELECT ON PS.PSDBOWNER TO #{new_connect_id};")
    connect_sql.puts("GRANT SELECT ON #{access_id}.PSSTATUS TO #{new_connect_id};")
    connect_sql.puts("GRANT SELECT ON #{access_id}.PSOPRDEFN TO #{new_connect_id};")
    connect_sql.puts("GRANT SELECT ON #{access_id}.PSACCESSPRFL TO #{new_connect_id};")

    if tools_release[0,4][-1,1].to_i > 4
      Puppet.debug("Tools version is 8.55 or later, granting to PSACCESSPROFILE table")
      connect_sql.puts("GRANT SELECT on #{access_id}.PSACCESSPROFILE to #{new_connect_id};")
    end
    connect_sql.close
    File.chmod(0755, connect_sql_path)
    Puppet.debug(File.read(connect_sql_path).gsub(new_connect_pwd, '****'))

    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, connect_sql_path, oracle_user)
    if sql_output.include?('ERROR')
      fail("Error updating connect information for database: #{database_name}")
    end
    if Facter.value(:osfamily) != 'windows'
      # upgrade the container/PDB to match the Oracle home patches
      rand_num = rand(1000)
      upg_sql_path = File.join(temp_dir_name, "upg-#{rand_num}.sql")
      upg_sql = File.open(upg_sql_path, 'w')

      if rac_db == true
        # make cluster database false
        sql_command = "ALTER SYSTEM SET CLUSTER_DATABASE=FALSE SCOPE=SPFILE"
        sql_output = execute_sql_command(oracle_home_dir, container_instance_name, sql_command, resource[:oracle_user])
        if sql_output.include?('ERROR')
          fail("Error modifying container #{container_instance_name}, Error: #{sql_output}")
        end
        # shutdown the RAC database
        srvctl_cmd = File.join(oracle_home_dir, 'bin', 'srvctl')
        if Facter.value(:osfamily) == 'windows'
          db_stop_cmd = "#{srvctl_cmd} stop database -d #{container_name} -o immediate"
          oracle_home_dir_norm = oracle_home_dir.gsub('/', '\\')
        else
          db_stop_cmd = "su #{resource[:oracle_user]} -c \"#{srvctl_cmd} stop database -d #{container_name} -o immediate\""
          oracle_home_dir_norm = oracle_home_dir
        end
        Puppet.debug("RAC Database stop command #{db_stop_cmd}")
        ENV['ORACLE_HOME'] = oracle_home_dir_norm

        begin
          execute_command(db_stop_cmd, env={"ORACLE_HOME"=>oracle_home_dir_norm})
          Puppet.debug('RAC Database stopped successfully')
        rescue Puppet::ExecutionFailure => e
          raise Puppet::ExecutionFailure, "RAC Database stop failed: #{e.message}"
        end
      else
        upg_sql.puts("SHUTDOWN IMMEDIATE;")
      end
      upg_sql.puts("STARTUP UPGRADE;")
      upg_sql.puts("ALTER PLUGGABLE DATABASE ALL OPEN UPGRADE;")
      upg_sql.close
      File.chmod(0755, upg_sql_path)
      Puppet.debug(File.read(upg_sql_path))

      sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, upg_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error starting container #{container_name} for upgrade, Error: #{sql_output}")
      end

      ENV['ORACLE_SID'] = container_instance_name
      # extract sqlpatch from DPK's
      require 'pathname'
      database_dir = resource[:database_dir]
      Puppet.debug(database_dir)
      base_dir = Pathname.new(database_dir).parent.parent.parent
      Puppet.debug(base_dir)
      extract_tgz = File.join('/bin', 'tar')
      Puppet.debug("Going to extract patch Directory")
      patch_dir = File.join(oracle_home_dir, 'sqlpatch')
      cmd_output = File.join(base_dir,'dpk','archives','sqlpatch.tgz')
      Puppet.debug(patch_dir)
      Puppet.debug(cmd_output)
      if FileTest.exists?(cmd_output) == true 
        system("#{extract_tgz} xvzf #{cmd_output} -C #{patch_dir}")
        File.chmod(0755, patch_dir)
      end
      # run the datapatch script
      datapatch_cmd = File.join(oracle_home_dir, 'OPatch', 'datapatch')
      if Facter.value(:osfamily) == 'windows'
        db_upg_cmd = "#{datapatch_cmd} -verbose"
        oracle_home_dir_norm = oracle_home_dir.gsub('/', '\\')
      else
        db_upg_cmd = "su #{resource[:oracle_user]} -c \"#{datapatch_cmd} -verbose -ignorable_errors=ORA-04063,ORA-01435,ORA-04043,ORA-00942\""
        oracle_home_dir_norm = oracle_home_dir
      end
      Puppet.debug("Database patch command #{db_upg_cmd}")
      ENV['ORACLE_HOME'] = oracle_home_dir_norm
      begin
        execute_command(db_upg_cmd, env={"ORACLE_HOME"=>oracle_home_dir_norm})
        Puppet.debug('Container/PDBs upgraded successfully')
      rescue Puppet::ExecutionFailure => e
        raise Puppet::ExecutionFailure, "Container/PDB upgrade failed: #{e.message}"
      end


      sql_countviolations_command = "select * from pdb_plug_in_violations where TYPE='ERROR' and STATUS = 'PENDING' and name = '#{database_name}'"
      sql_countviolations_output = execute_sql_command(oracle_home_dir, container_instance_name, sql_countviolations_command, resource[:oracle_user])
      if (sql_countviolations_output.nil?)
        Puppet.debug("Nothing in table to force datapatch #{container_instance_name}")
      else
        Puppet.debug("INFO: datapatch sql output: #{sql_countviolations_output}")

        Puppet.debug("INFO: Applying datapatch in normal mode")
        upg_normal_sql_path = File.join(temp_dir_name, "upg_normal-#{rand_num}.sql")
        upg_normal_sql = File.open(upg_normal_sql_path, 'w')
        upg_normal_sql.puts("SHUTDOWN IMMEDIATE;")
        upg_normal_sql.puts("STARTUP;")
        upg_normal_sql.puts("ALTER PLUGGABLE DATABASE ALL CLOSE;")
        upg_normal_sql.puts("ALTER PLUGGABLE DATABASE ALL OPEN;")
        upg_normal_sql.close
        File.chmod(0755, upg_normal_sql_path)
        Puppet.debug(File.read(upg_normal_sql_path))

        sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, upg_normal_sql_path, oracle_user)
        if sql_output.include?('ERROR')
          fail("Error starting container #{container_name} for upg_normalrade, Error: #{sql_output}")
        end

        # run the datapatch script in normal mode. This is to ensure the MLR patches are also applied successfully
        datapatch_normal_cmd = File.join(oracle_home_dir, 'OPatch', 'datapatch')
        if Facter.value(:osfamily) == 'windows'
          db_normal_upg_cmd = "#{datapatch_normal_cmd} -verbose"
          oracle_home_dir_norm = oracle_home_dir.gsub('/', '\\')
        else
          db_normal_upg_cmd = "su #{resource[:oracle_user]} -c \"#{datapatch_cmd} -verbose\""
          oracle_home_dir_norm = oracle_home_dir
        end
        Puppet.debug("Database patch command #{db_normal_upg_cmd}")
        ENV['ORACLE_HOME'] = oracle_home_dir_norm
        begin
          execute_command(db_normal_upg_cmd, env={"ORACLE_HOME"=>oracle_home_dir_norm})
          Puppet.debug('Container/PDBs upgraded successfully')
        rescue Puppet::ExecutionFailure => e
          raise Puppet::ExecutionFailure, "Container/PDB upgrade failed: #{e.message}"
        end

        upg_normal_sql_path = File.join(temp_dir_name, "upg_normal-#{rand_num}.sql")
        upg_normal_sql = File.open(upg_normal_sql_path, 'w')
        upg_normal_sql.puts("SHUTDOWN IMMEDIATE;")
        upg_normal_sql.puts("STARTUP;")
        upg_normal_sql.puts("ALTER PLUGGABLE DATABASE ALL CLOSE;")
        upg_normal_sql.puts("ALTER PLUGGABLE DATABASE ALL OPEN;")
        upg_normal_sql.close
        File.chmod(0755, upg_normal_sql_path)
        Puppet.debug(File.read(upg_normal_sql_path))

        sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, upg_normal_sql_path, oracle_user)
        if sql_output.include?('ERROR')
          fail("Error starting container #{container_name} for upg_normalrade, Error: #{sql_output}")
        end

        sql_countviolations_output = execute_sql_command(oracle_home_dir, container_instance_name, sql_countviolations_command, resource[:oracle_user])
        if (sql_countviolations_output.nil?)
          Puppet.debug("Nothing in table to force datapatch #{container_instance_name}")
        else
          Puppet.debug("INFO: datapatch sql output: #{sql_countviolations_output}")
        end
      end

      if rac_db == true
        sql_command = "ALTER SYSTEM SET CLUSTER_DATABASE=TRUE SCOPE=SPFILE"
        sql_output = execute_sql_command(oracle_home_dir, container_instance_name, sql_command, resource[:oracle_user])
        if sql_output.include?('ERROR')
          fail("Error updating container #{container_instance_name}, Error: #{sql_output}")
        end
      end

      # stop the database
      sql_command = 'SHUTDOWN IMMEDIATE'
      sql_output = execute_sql_command(oracle_home_dir, container_instance_name, sql_command, resource[:oracle_user])
      if sql_output.include?('ERROR')
        fail("Error stopping container #{container_instance_name}, Error: #{sql_output}")
      end

      # restart the container
      start_sql_path = File.join(temp_dir_name, "start-cdb.sql")
      start_sql = File.open(start_sql_path, 'w')

      if rac_db == true
        # start the RAC database
        srvctl_cmd = File.join(oracle_home_dir, 'bin', 'srvctl')
        if Facter.value(:osfamily) == 'windows'
          db_start_cmd = "#{srvctl_cmd} start database -d #{container_name}"
          oracle_home_dir_norm = oracle_home_dir.gsub('/', '\\')
        else
          db_start_cmd = "su #{resource[:oracle_user]} -c \"#{srvctl_cmd} start database -d #{container_name}\""
          oracle_home_dir_norm = oracle_home_dir
        end
        Puppet.debug("RAC Database start command #{db_start_cmd}")
        ENV['ORACLE_HOME'] = oracle_home_dir_norm

        begin
          execute_command(db_start_cmd, env={"ORACLE_HOME"=>oracle_home_dir_norm})
          Puppet.debug('RAC Database started successfully')
        rescue Puppet::ExecutionFailure => e
          raise Puppet::ExecutionFailure, "RAC Database start failed: #{e.message}"
        end
      else
        start_sql.puts("STARTUP;")
      end
      start_sql.puts("ALTER PLUGGABLE DATABASE ALL CLOSE;")
      start_sql.puts("ALTER PLUGGABLE DATABASE ALL OPEN;")
      start_sql.close
      File.chmod(0755, start_sql_path)
      Puppet.debug(File.read(start_sql_path))

      sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, start_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error starting container #{container_instance_name} normal, Error: #{sql_output}")
      end
    end
  end

  def destroy
    container_name = resource[:container_name]
    database_name = resource[:database_name]
    Puppet.debug("Destroy called for database: #{database_name}")

    database_dir = resource[:database_dir]
    oracle_home_dir = resource[:oracle_home_dir]

    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end

    # close the database
    pdb_close_sql_file = sql_command_file(template('puppet:///modules/pt_config/pt_psft_database/pdb_scripts/closepdb.sql', binding))
    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name,
                             pdb_close_sql_file, resource[:oracle_user],
                             database_name)
    if sql_output.include?("ORA-65020") == false
      if sql_output.include?('ERROR')
        fail("Error closing database #{database_name}, Error: #{sql_output}")
      end
    else
      Puppet.debug("Pluggable database #{database_name} already closed")
    end
    # unplug the database
    pdb_unplug_sql_file = sql_command_file(template('puppet:///modules/pt_config/pt_psft_database/pdb_scripts/unplugpdb.sql', binding))
    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name,
                             pdb_unplug_sql_file, resource[:oracle_user],
                             database_name,
                             File.join(database_dir, "#{database_name}unplug.xml"))
    if sql_output.include?('ERROR')
      fail("Error unplugging database #{database_name}, Error: #{sql_output}")
    end

    # drop the database
    sql_command = "DROP PLUGGABLE DATABASE #{database_name}"
    sql_output = execute_sql_command(oracle_home_dir, container_instance_name,
                                    sql_command, resource[:oracle_user])
    if sql_output.include?('ERROR')
      fail("Error dropping Oracle database: #{database_name}")
    end
    FileUtils.mv(File.join(database_dir, "#{database_name}unplug.xml"),
                 File.join(database_dir, "#{database_name}.xml"))

    if resource[:new_container] == true
      remove_container_database(container_name)
    else
      Puppet.debug("Existing container, not removing it")
    end
  end

  def flush
    database_name = resource[:database_name]
    oracle_home_dir = resource[:oracle_home_dir]
    temp_dir_name = Dir.tmpdir()
    rand_num = rand(1000)
    Puppet.debug("Flush called for database: #{database_name}")

    if resource[:ensure] != :present
      return
    end

    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_name = resource[:container_name]
      container_instance_name = container_name
    end

    # check the status of the database and start it if its stopped
    sql_command = "ALTER PLUGGABLE DATABASE #{database_name} OPEN"
    sql_output = execute_sql_command(oracle_home_dir, container_instance_name,
                                    sql_command, resource[:oracle_user])
    if sql_output.include?("ORA-65019") == false
      if sql_output.include?('ERROR')
        fail("Error opening database #{database_name}, Error: #{sql_output}")
      end
    else
      Puppet.debug("Pluggable database #{database_name} already opened")
    end

    #  datapatch applied forcefully if it is in PENDING state
    begin
      sql_command = "select * from pdb_plug_in_violations where TYPE='ERROR' and STATUS = 'PENDING' and name = '#{database_name}'"
      sql_output_combined = execute_sql_command(oracle_home_dir, container_instance_name, sql_command, resource[:oracle_user])
      if (sql_output_combined.nil?)
        Puppet.debug("Nothing in table to force datapatch #{container_instance_name}")
      else
        patch_list = []
        if sql_output_combined.match(/\d{8}/)
          for sql_output in sql_output_combined
            result =/[[:digit:]]{8,10}(\/|\)| )/.match(sql_output)
            if result.length > 0
              element = result[0][0..-2]
              Puppet.debug("extracted elemet: #{element}")
              patch_list.push(element)
            end
          end

          Puppet.debug("datapatch sql output: #{sql_output_combined}")
          if !(patch_list.nil?)
            # open database in upgrade mode
            begin
              Puppet.debug("datapatch patch list inside: #{patch_list}")
              Puppet.debug("Applying datapatch in upgrade mode for forcefully datapatch")
              start_upgrade_sql_path = File.join(temp_dir_name, "start_upgrade-#{rand_num}.sql")
              start_upgrade_sql = File.open(start_upgrade_sql_path, 'w')
              start_upgrade_sql.puts("SHUTDOWN IMMEDIATE;")
              start_upgrade_sql.puts("STARTUP UPGRADE;")
              start_upgrade_sql.puts("ALTER PLUGGABLE DATABASE #{database_name} OPEN UPGRADE;")
              start_upgrade_sql.close
              File.chmod(0755, start_upgrade_sql_path)
              Puppet.debug(File.read(start_upgrade_sql_path))
              sql_output_upgmode = execute_sql_command_file(oracle_home_dir, container_instance_name, start_upgrade_sql_path, resource[:oracle_user])
              if sql_output_upgmode.include?('ERROR')
                fail("Error opening database #{database_name}, Error: #{sql_output_upgmode}")
              else
                Puppet.debug("Pluggable database #{database_name} already upgrade mode")
              end
            rescue Exception => e
              Puppet.debug("Exception #{e}")
            end
            Puppet.debug("datapatch patch list inside: #{patch_list}")
            for pl in patch_list.uniq
              # run the datapatch script
              datapatch_cmd = File.join(oracle_home_dir, 'OPatch', 'datapatch')
              if Facter.value(:osfamily) == 'windows'
                db_upg_cmd = "#{datapatch_cmd} -verbose"
                oracle_home_dir_norm = oracle_home_dir.gsub('/', '\\')
              else
                db_upg_cmd = "su #{resource[:oracle_user]} -c \"#{datapatch_cmd} -bundle_series PSU -apply #{pl} -pdbs #{database_name} -f\""
                oracle_home_dir_norm = oracle_home_dir
              end
              Puppet.debug("Database patch command #{db_upg_cmd}")
              ENV['ORACLE_HOME'] = oracle_home_dir_norm
              begin
                execute_command(db_upg_cmd, env={"ORACLE_HOME"=>oracle_home_dir_norm})
                Puppet.debug('Datapatch forcefully apply successfully')
              rescue Puppet::ExecutionFailure => e
                raise Puppet::ExecutionFailure, "Datapatch forcefully apply failed: #{e.message}"
              end
            end
            # open database in normal mode
            Puppet.debug("INFO: Applying datapatch in normal mode for forcefully datapatch")
            upg_violation_open_sql_path = File.join(temp_dir_name, "upg_violation_open-#{rand_num}.sql")
            Puppet.debug("INFO:Printing PATH of upg_violation_open_sql_path #{upg_violation_open_sql_path}")
            upg_violation_open_sql = File.open(upg_violation_open_sql_path, 'w')
            upg_violation_open_sql.puts("SHUTDOWN IMMEDIATE;")
            upg_violation_open_sql.puts("STARTUP;")
            upg_violation_open_sql.puts("ALTER PLUGGABLE DATABASE #{database_name} CLOSE;")
            upg_violation_open_sql.puts("ALTER PLUGGABLE DATABASE #{database_name} OPEN;")
            upg_violation_open_sql.close
            File.chmod(0755, upg_violation_open_sql_path)
            Puppet.debug(File.read(upg_violation_open_sql_path))
            sql_output_upgmode_open = execute_sql_command_file(oracle_home_dir, container_instance_name, upg_violation_open_sql_path, resource[:oracle_user])
            if sql_output_upgmode_open.include?('ERROR')
              fail("Error opening database #{database_name}, Error: #{sql_output_upgmode_open}")
            else
              Puppet.debug("Pluggable database #{database_name} already opened")
            end
          end
        end
      end
    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Exception Applying while Datapatch:  #{e.message}"
    end
    change_db_admin_pwd(container_instance_name)
    # change_db_access_pwd(container_instance_name) # Removing as its taken care in mid tier
    if Facter.value(:osfamily) != 'windows'
      remote_login_pwd(container_instance_name)
    end
    # lock_db_ps_users(container_instance_name)
  end

  def self.instances
    []
  end


  private

  def validate_parameters
    # check to make sure Oracle Home exists
    oracle_home_dir = resource[:oracle_home_dir]

    if Facter.value(:osfamily) != 'windows'
      oracle_user = resource[:oracle_user]
      oracle_user_group = resource[:oracle_user_group]

      check_user_group(oracle_user, oracle_user_group)
    end

    ENV['ORACLE_HOME'] = oracle_home_dir
    cur_path = ENV['PATH']
    if Facter.value(:osfamily) != 'windows'
      new_path = "#{oracle_home_dir}/bin:#{cur_path}"
    else
      new_path = "#{oracle_home_dir}/bin;#{cur_path}"
    end
    ENV['PATH'] = new_path

    if Facter.value(:osfamily) == 'windows'
      oracle_version_cmd = 'sqlplus.exe -v'
    else
      cur_ld_path = ENV['LD_LIBRARY_PATH']
      ENV['LD_LIBRARY_PATH'] = "#{oracle_home_dir}/lib:#{cur_ld_path}"

      oracle_user = resource[:oracle_user]
      oracle_version_cmd = "su #{oracle_user} -c \"sqlplus -v\""
    end
    Puppet.debug("Oracle version command: #{oracle_version_cmd}")

    # validate to make sure Oracle is the right version
    error_str = ''
    begin
      Open3.popen3(oracle_version_cmd) do |stdin, out, err|
        stdin.close
        out_str = out.read
        error_str = err.read

        ENV['PATH'] = cur_path

        needed_orcl_release = '12.1.0.2.0'
        release = out_str.split(' ')[2]
        Puppet.debug("Oracle version: #{release}")
        if release != needed_orcl_release
          fail("Oracle home provided is of wrong version #{release}.\n" +
               "Install Oracle 64 bit Release #{needed_orcl_release}")
        end
      end
    rescue
      ENV['PATH'] = cur_path
      fail("Error getting Oracle Home #{oracle_home_dir} version" +
           "Error: #{error_str}")
    end
    database_dir = resource[:database_dir]
    if FileTest.directory?(database_dir) == false
      if resource[:ensure] == :present
        fail("Database files directory #{database_dir} does not exists.\n" +
             "Ensure that the database files are present under that directory.")
      else
        return
      end
    end
    # check if the database files directory is a valid directory
    database_system_file = File.join(database_dir, 'system01.dbf')
    if File.exist?(database_system_file) == false
      fail("Database files directory #{database_dir} appears to be corrupted")
    end
  end

  def check_container_exists?(container_name)

    Puppet.debug("Checking if container #{container_name} exists")
    rac_db = resource[:rac_database]
    Puppet.debug("Is RAC database #{rac_db}")
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end

    oracle_home_dir = resource[:oracle_home_dir]
    oracle_base_dir = get_oracle_base_dir(oracle_home_dir)

    if Facter.value(:osfamily) == 'windows'
      db_service_name = "OracleService#{container_instance_name}"
      begin
        if Service.status(db_service_name).current_state != 'running'
          begin
            Service.start(db_service_name)
          rescue
            Puppet.debug("Unable to start database service #{db_service_name}")
            fail("Unable to start database service #{db_service_name}")
          end
        end
      rescue SystemCallError => e
        if e.message.include?('The specified service does not exist') == false
          Puppet.debug("Unable to get the status of database service #{db_service_name}")
          fail("Unable to get the status of database service #{db_service_name}")
        else
          return false
        end
      end
    end
    if Facter.value(:osfamily) == 'windows'
      database_init_file = File.join(oracle_home_dir, 'database', "init#{container_instance_name}.ora")
    else
      database_init_file = File.join(oracle_home_dir, 'dbs', "init#{container_instance_name}.ora")
    end
    Puppet.debug("Database init file: #{database_init_file}")
    if File.exist?(database_init_file) == false
      Puppet.debug("Database init file doesn't exist, checking for spfile")
      # check if the spfile exists
      if Facter.value(:osfamily) == 'windows'
        database_sp_file = File.join(oracle_home_dir, 'database', "spfile#{container_instance_name}.ora")
      else
        database_sp_file = File.join(oracle_home_dir, 'dbs', "spfile#{container_instance_name}.ora")
      end
      Puppet.debug("Database sp file: #{database_sp_file}")
      if File.exist?(database_sp_file) == false
        Puppet.debug("Database sp file doesn't exist also")
        return false
      end
    end
    # ensure there are CDB directories and files
    database_dir = resource[:database_dir]
    container_base_dir = File.dirname(database_dir)
    if container_base_dir.include?(container_name)
      container_db_dir = container_base_dir
    else
      container_db_dir = File.join(container_base_dir, container_name)
    end
    if File.directory?(container_db_dir) == false
      Puppet.debug("Container directory #{container_db_dir} does not exists")
      return false
    end
    if rac_db == false
    container_pdb_dir = File.join(container_db_dir, 'pdbseed')
    if File.directory?(container_pdb_dir) == false
        Puppet.debug("Container PDB seed directory #{container_pdb_dir} does not exists")
      return false
    end
    # ensure there are CDB datafiles
    if Dir.glob(File.join(container_db_dir, 'system01.dbf'), File::FNM_CASEFOLD).empty?
        Puppet.debug("Container database system file does not exists")
      return false
    end
    if Dir.glob(File.join(container_pdb_dir, 'system01.dbf'), File::FNM_CASEFOLD).empty?
        Puppet.debug("Container PDB seed database system file does not exists")
      return false
      end
    end
    # start the database
    sql_command = 'startup'
    sql_output = execute_sql_command(oracle_home_dir, container_instance_name,
                                    sql_command, resource[:oracle_user])
    if sql_output.include?('ORACLE instance started') or
       sql_output.include?('ORA-01081')
       return true
    else
      fail("Error starting Oracle database: #{container_instance_name}")
    end
  end

  def check_database_plugged?(container_name, database_name)
    database_dir = resource[:database_dir]
    oracle_home_dir = resource[:oracle_home_dir]

    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end

    # verify if the database is already plugged
    pdb_check_sql_file = sql_command_file(template('puppet:///modules/pt_config/pt_psft_database/pdb_scripts/checkpdb.sql', binding))
    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name,
                             pdb_check_sql_file, resource[:oracle_user],
                             container_name, database_name)
    cdb_exists = false
    seed_exists = false
    pdb_exists = false
    pdb_is_open = false

    if sql_output.include?('CDB')
      cdb_exists = true
    end
    if sql_output.include?('PDBSEED')
      seed_exists = true
    end

    if sql_output.include?("#{database_name} READ WRITE")
      pdb_exists = true
      pdb_is_open = true
    elsif sql_output.include?("#{database_name} MOUNTED")
      pdb_exists = true
    end
    if cdb_exists == false or seed_exists == false
      fail("Container database #{container_name} is corrupt")
    end

    if pdb_exists
      if pdb_is_open
        return true
      else
        Puppet.debug("Pluggable database #{database_name} is closed")

        if resource[:ensure] == :present
          sql_command = "ALTER PLUGGABLE DATABASE #{database_name} OPEN"
          sql_output = execute_sql_command(oracle_home_dir, container_instance_name,
                                           sql_command, resource[:oracle_user])
          if sql_output.include?('ERROR')
            fail("Error opening database #{database_name}, Error: #{sql_output}")
          else
            Puppet.debug("Pluggable database #{database_name} already opened")
          end
        end
        return true
      end
    else
        return false
    end
  end

  def get_oracle_base_dir(oracle_home_dir)

    oracle_base_dir = nil
    oracle_home_prop_file = File.join(oracle_home_dir,
                                    'inventory', 'ContentsXML',
                                    'oraclehomeproperties.xml')

    file = File.new(oracle_home_prop_file)
    doc = REXML::Document.new file
    doc.elements.each("ORACLEHOME_INFO/PROPERTY_LIST/PROPERTY") do |elem|
      if elem.attributes['NAME'] == 'ORACLE_BASE'
        oracle_base_dir = elem.attributes['VAL']
      end
    end
    file.close
    if oracle_base_dir.nil?
      fail("Oracle Home #{oracle_home_dir} is not valid")
    end
    Puppet.debug("Oracle base home: #{oracle_base_dir}")
    return oracle_base_dir
  end

  def create_container_database(container_name)
    oracle_home_dir = resource[:oracle_home_dir]
    using_cold_backup = resource[:cold_backup_container]

    if using_cold_backup == true
      create_container_using_coldbackup(container_name)
    else
      create_container_using_dbca(container_name)
    end
    sql_command = 'ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED'
    sql_output = execute_sql_command(oracle_home_dir, container_name,
                                    sql_command, resource[:oracle_user])
    if sql_output.include?('ERROR')
      fail("Error setting up PASSWORD_LIFE_TIME for database #{container_name}")
    end
    sql_command = 'ALTER PROFILE DEFAULT LIMIT PASSWORD_GRACE_TIME UNLIMITED'
    sql_output = execute_sql_command(oracle_home_dir, container_name,
                                    sql_command, resource[:oracle_user])
    if sql_output.include?('ERROR')
      fail("Error setting up PASSWORD_GRACE_TIME for database #{container_name}")
    end
  end

  def create_container_using_dbca(container_name)
    database_dir = resource[:database_dir]
    oracle_home_dir = resource[:oracle_home_dir]
    Puppet.debug("Creating container database #{container_name} using scripts")

    # make sure the container settings are given
    if @container_hash.nil? || @container_hash.size == 0
      raise ArgumentError,
            "container_settings needs to be specified to create a database container"
    end

    rac_db = resource[:rac_database]
    container_base_dir = File.dirname(database_dir)
    if container_base_dir.include?(container_name)
      container_db_dir = container_base_dir
    else
      container_db_dir = File.join(container_base_dir, container_name)
    end
    if File.directory?(container_db_dir)
      # remove the directory
      FileUtils.rm_rf(container_db_dir)
    end
    Puppet.debug("Container root directory #{container_base_dir}")

    container_init_content = template('puppet:///modules/pt_config/pt_psft_database/cdb_scripts/init.ora.erb',
                                      binding)

    # update the init file with user custom settings
    @container_hash.each do |init_key, init_val|
      Puppet.debug("Containing setting: [#{init_key.to_s}=#{init_val}]")

      if init_key == :nls_characterset || init_key == :nls_nchar_characterset
        next
      end
      # update/insert the init parameter with user value if present
      init_param = init_key.to_s
      init_param_reg = Regexp.new("#{init_param}=.*")
      Puppet.debug("Init param regular expression #{init_param_reg}")

      if container_init_content.lines.to_a.grep(init_param_reg).any?
        Puppet.debug("#{init_param} is present in the init file, updating it with value #{init_val}")
        container_init_content = container_init_content.gsub(init_param_reg, "#{init_param}=#{init_val}")
      else
        Puppet.debug("#{init_param} is not present in the init file, adding it with value #{init_val}")
        container_init_content = "#{container_init_content}\n#{init_param}=#{init_val}"
      end
    end

    if Facter.value(:osfamily) == 'windows'
      oracle_home_dir_norm = oracle_home_dir.gsub('/', '\\')
      container_base_dir_norm = container_base_dir.gsub('/', '\\')
    else
      oracle_home_dir_norm = oracle_home_dir
      container_base_dir_norm = container_base_dir
    end

    Puppet.debug("Oracle home #{oracle_home_dir_norm}")
    ENV['ORACLE_HOME'] = oracle_home_dir_norm

    # use DBCA and create container database
    dbca_cmd = "dbca -silent -createDatabase -templateName General_Purpose.dbc -gdbName #{container_name} -sid #{container_name} -createAsContainerDatabase true -numberOfPdbs 0 -sysPassword manager -systemPassword manager -emConfiguration NONE -datafileDestination #{container_base_dir_norm} -storageType FS -characterSet #{@container_hash[:nls_characterset]} -nationalCharacterSet  #{@container_hash[:nls_nchar_characterset]} -initParams "

    container_init_params = container_init_content.lines.to_a
    container_init_params.each do |init_param|
      if init_param.start_with?("#") || /\S/ !~ init_param ||
         init_param.start_with?('dispatchers') || init_param.start_with?('control_files') ||
         init_param.start_with?('db_block_size') || init_param.start_with?('compatible') ||
         init_param.start_with?('undo_tablespace') || init_param.start_with?('sga_target') ||
         init_param.start_with?('sga_max_size') || init_param.start_with?('pga_aggregate_target')
        next
      end
      if init_param[-1, 1] == "\n"
      	init_param = init_param.chop
      end
      Puppet.debug("Container init param: #{init_param}")
      dbca_cmd << init_param
      dbca_cmd << ","
    end
    if Facter.value(:osfamily) == 'windows'
      # remove container service if present
      remove_cdb_service(container_name)

      cont_creation_cmd = "set ORACLE_HOME=#{oracle_home_dir_norm} && set TNS_ADMIN=%ORACLE_HOME%\\network\\admin && #{oracle_home_dir_norm}\\bin\\#{dbca_cmd}"
    else
      cont_creation_cmd = "su #{resource[:oracle_user]} -c \"export ORACLE_HOME=#{oracle_home_dir_norm} && export TNS_ADMIN=$ORACLE_HOME/network/admin && $ORACLE_HOME/bin/#{dbca_cmd}\""
    end

    begin
      command_output = execute_command(cont_creation_cmd, env={"ORACLE_HOME"=>oracle_home_dir_norm})
      if command_output.include?('DBCA Operation failed')
        fail("Error creating container database #{container_name} using dbca")
      end
      Puppet.debug('Container database creation successful successfully')

      remove_cdb_misc_services(container_name)

      update_container_listener(oracle_home_dir, container_name, true)

    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Container database creation failed: #{e.message}"
    end
  end

  def update_container_listener(oracle_home_dir, container_name, spfile_exists)
    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end
    ENV['ORACLE_SID'] = container_instance_name

    # update the CDB with listener information. This allows to use non default
    # listener name and port
    listener_port = 1521
    db_listener_file = File.join(oracle_home_dir, 'network', 'admin', 'listener.ora')
    listener_file_content = File.read(db_listener_file)
    listener_port_match_regex = Regexp.new('(^.*)(PORT)( = )([0-9]+)(\).*)')
    listener_port_match_found = listener_file_content.match(listener_port_match_regex)
    if listener_port_match_found.nil? == false
      listener_port = listener_port_match_found[4]
    end
    temp_dir_name = Dir.tmpdir()

    rand_num = rand(1000)
    listener_sql_path = File.join(temp_dir_name, "listener-#{rand_num}.sql")
    listener_sql = File.open(listener_sql_path, 'w')

    if spfile_exists == false
      listener_sql.puts("create spfile from pfile;")
      listener_sql.puts("shutdown immediate;")
      listener_sql.puts("startup;")
    end
    host_name = Facter.value(:fqdn)
    listener_sql.puts("alter system set LOCAL_LISTENER='(ADDRESS = (PROTOCOL=TCP)(HOST=#{host_name})(PORT=#{listener_port}))' scope=both;")
    listener_sql.close
    File.chmod(0755, listener_sql_path)
    Puppet.debug(File.read(listener_sql_path))

    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, listener_sql_path, resource[:oracle_user])
    if sql_output.include?('ERROR')
      fail("Error updating listener info on container database : #{container_name}")
    end
    if spfile_exists == false
      # get the spfile value
      rand_num = rand(1000)
      spfile_sql_path = File.join(temp_dir_name, "spfile-#{rand_num}.sql")
      spfile_sql = File.open(spfile_sql_path, 'w')
      spfile_sql.puts("SET HEADING OFF;")
      spfile_sql.puts("SET FEEDBACK OFF;")
      spfile_sql.puts("SET LINESIZE 200;")
      spfile_sql.puts("COLUMN VALUE_COL_PLUS_SHOW_PARAM FORMAT a80;")
      spfile_sql.puts("SHOW PARAMETER SPFILE;")
      spfile_sql.close
      File.chmod(0755, spfile_sql_path)
      Puppet.debug(File.read(spfile_sql_path))

      sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name, spfile_sql_path, resource[:oracle_user])
      if sql_output.include?('ERROR')
        fail("Error getting spfile location of the database: #{container_name}")
      end
      spfile_location = sql_output.strip.split[2]
      Puppet.debug("SPFile location of container database: #{spfile_location}")

      if Facter.value(:osfamily) == 'windows'
        container_init_file = File.join(oracle_home_dir, 'database', "init#{container_instance_name}.ora")
      else
        container_init_file = File.join(oracle_home_dir, 'dbs', "init#{container_instance_name}.ora")
      end
      Puppet.debug("Updating init file with spfile location: #{spfile_location}")
      File.open(container_init_file, 'w') { |f| f.write("spfile=#{spfile_location}") }
    end
  end

  def create_container_using_coldbackup(container_name)
    Puppet.debug("Creating container database #{container_name} using cold-backup")
    database_dir = resource[:database_dir]

    # validate to make sure the container archive file is present
    container_archive_file = resource[:container_backup_file]
    if File.exist?(container_archive_file) == false
      fail("Container database archive file #{container_archive_file} does not exists")
    end

    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end
    container_base_dir = File.dirname(database_dir)
    if container_base_dir.include?(container_name)
      container_db_dir = container_base_dir
    else
      container_db_dir = File.join(container_base_dir, container_name)
    end
    if File.directory?(container_db_dir)
      # remove the directory
      FileUtils.rm_rf(container_db_dir)
    end
    # create the directory the holds container db files
    FileUtils.makedirs(container_db_dir)

    # extract the container archive
    oracle_home_dir = resource[:oracle_home_dir]

    begin
      extract_cmd = File.join(oracle_home_dir, 'bin', 'unzip')
      if Facter.value(:osfamily) == 'windows'
        extract_cmd = "#{extract_cmd}.exe"
      end
      command = "#{extract_cmd} -q #{container_archive_file} -d #{container_db_dir}"
      execute_command(command)

    rescue Puppet::ExecutionFailure => e
      raise Puppet::Error, "Extraction of container zip file faled"
    end

    container_init_content = template('puppet:///modules/pt_config/pt_psft_database/cdb_scripts/init.ora.erb',
                                      binding)
    if Facter.value(:osfamily) == 'windows'
      container_init_content = container_init_content.gsub('/', '\\')
      container_init_file = File.join(oracle_home_dir, 'database', "init#{container_instance_name}.ora")
    else
      container_init_file = File.join(oracle_home_dir, 'dbs', "init#{container_instance_name}.ora")
    end
    File.open(container_init_file, 'w') { |f| f.write(container_init_content) }
    if File.file?(container_init_file) == false
      Puppet.debug("Container init file #{container_init_file} does not exist")
      raise Puppet::Error, "Container init file #{container_init_file} does not exist"
    end
    if Facter.value(:osfamily) == 'windows'
      create_cdb_service(oracle_home_dir, container_name, container_init_file)
    else
      oracle_user = resource[:oracle_user]
      oracle_user_group = resource[:oracle_user_group]

      FileUtils.chown_R(oracle_user, oracle_user_group, container_db_dir)
      FileUtils.chown(oracle_user, oracle_user_group, container_init_file)
    end

    # update the load.sql file
    load_sql_file = File.join(container_db_dir, 'load.sql')
    load_sql_content = File.read(load_sql_file)
    if Facter.value(:osfamily) != 'windows'
      load_sql_content = load_sql_content.gsub(/spool logs.*/, 'STARTUP NOMOUNT')
    else
      load_sql_content = load_sql_content.gsub(/spool logs.*\n/, '')
      container_db_dir = container_db_dir.gsub('/', '\\')
      container_db_dir = container_db_dir.gsub(':', ':\\')
    end
    Puppet.debug("Container database directory #{container_db_dir}")
    load_sql_content = load_sql_content.gsub(/spool.*\n/, '')
    load_sql_content = load_sql_content.gsub(/&1\\PDBATTACH\\ORADATA\\&2/, "#{container_db_dir}")
    load_sql_content = load_sql_content.gsub(/&2/, "#{container_name}")
    if Facter.value(:osfamily) != 'windows'
      load_sql_content = load_sql_content.gsub(/\\/, '/')
      load_sql_content = load_sql_content.gsub(/\x0d/, '')
      load_sql_content = load_sql_content.gsub(/PDBSEED/, 'pdbseed')
    end
    File.open(load_sql_file, "w") { |file| file << load_sql_content }

    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name,
                                          load_sql_file, resource[:oracle_user], nil)
    if sql_output.include?('ERROR')
      fail("Error creating container database #{container_name}, Error: #{sql_output}")
    end
    update_container_listener(oracle_home_dir, container_name, false)
  end

  def create_cdb_service(oracle_home_dir, container_name, container_init_file)
    if Facter.value(:osfamily) != 'windows'
      return
    end
    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end
    oracle_home_dir_norm = oracle_home_dir.gsub('/', '\\')
    ENV['ORACLE_HOME'] = oracle_home_dir_norm
    ENV['ORACLE_SID'] = container_instance_name

    # create the database instance
    oradim_cmd="#{oracle_home_dir_norm}\\bin\\oradim.exe"
    container_init_file_norm = container_init_file.gsub('/', '\\')
    instance_cmd = "#{oradim_cmd} -new -sid #{container_instance_name} -intpwd manager -startmode auto -srvcstart system -pfile #{container_init_file_norm}"
    Puppet.debug("Instance creation command: #{instance_cmd}")

    begin
      command_output = Puppet::Util::Execution.execute(instance_cmd, :failonfail => true, :combine => true)
      Puppet.debug("Database instance #{container_name} created successfully")

      remove_cdb_misc_services(container_name)
    rescue Exception => e
      Puppet.debug("Database instance #{container_name} creation failed")
      raise Puppet::Error, "Database instance #{container_name} creation failed, Error: #{e.message}"
    end
  end

  def remove_cdb_misc_services(container_name)
    if Facter.value(:osfamily) != 'windows'
      return
    end
    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end
    # delete OracleJobScheduler service
    begin
      orcl_job_service = "OracleJobScheduler#{container_instance_name}"
      Service.delete(orcl_job_service)
      Puppet.debug("Service #{orcl_job_service} deleted successfully")
    rescue
      Puppet.debug("Failed to delete service #{orcl_job_service}")
    end

    # delete OracleVssWriter service
    orcl_vss_service = "OracleVssWriter#{container_instance_name}"
    begin
      Service.stop(orcl_vss_service)
      Puppet.debug("Service #{orcl_vss_service} stopped successfully")
      begin
        Service.delete(orcl_vss_service)
        Puppet.debug("Service #{orcl_vss_service} deleted successfully")
      rescue
        Puppet.debug("Failed to delete service #{orcl_vss_service}")
      end
    rescue
      Puppet.debug("Failed to stop service #{orcl_vss_service}")
    end
  end

  def remove_cdb_service(container_name)
    if Facter.value(:osfamily) != 'windows'
      return
    end
    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end
    # stop and delete database service
    db_service = "OracleService#{container_instance_name}"
    begin
      Service.stop(db_service)
      Puppet.debug("Service #{db_service} stopped successfully")
    rescue Exception => e
      Puppet.debug("Failed to stop database service for CDB #{container_name}: #{e.message}")
      system("sc stop #{db_service} > NUL")
    end
    begin
      Service.delete(db_service)
      Puppet.debug("Service #{db_service} deleted successfully")
    rescue Exception => e
      Puppet.debug("Failed to delete database service for CDB #{container_name}: #{e.message}")
      system("sc delete #{db_service} > NUL")
    end
  end

  def remove_container_database(container_name)
    rac_db = resource[:rac_database]
    if rac_db == true
      container_instance_name = resource[:container_instance_name]
    else
      container_instance_name = container_name
    end
    database_dir = resource[:database_dir]
    oracle_home_dir = resource[:oracle_home_dir]

    # get the list of the PDB's
    pdb_list_sql_file = sql_command_file(template('puppet:///modules/pt_config/pt_psft_database/pdb_scripts/listpdb.sql', binding))
    sql_output = execute_sql_command_file(oracle_home_dir, container_instance_name,
                                          pdb_list_sql_file, resource[:oracle_user])
    if sql_output.include?('READ WRITE') or sql_output.include?('MOUNT')
      return true
    elsif sql_output.include?('ERROR')
      fail("Error listing PDBs on container database : #{container_name}")
    end
    # no pdb's found in the container, shut it down
    sql_command = 'shutdown immediate'
    sql_output = execute_sql_command(oracle_home_dir, container_instance_name,
                                     sql_command, resource[:oracle_user])
    if sql_output.include?('ORACLE instance shut down') or sql_output.include?('ORA-01034')
      # remove the container DB files directory
      container_base_dir = File.dirname(database_dir)
      if File.directory?(container_base_dir)
        # remove the directory
        FileUtils.rm_rf(container_base_dir)
      end
      # remove the container init file
      if Facter.value(:osfamily) != 'windows'
        container_init_file = File.join(oracle_home_dir, 'dbs', "init#{container_instance_name}.ora")
        container_sp_file = File.join(oracle_home_dir, 'dbs', "spfile#{container_instance_name}.ora")
        container_lk_file = File.join(oracle_home_dir, 'dbs', "lk#{container_instance_name}")
        container_pw_file = File.join(oracle_home_dir, 'dbs', "orapw#{container_instance_name}")
      else
        container_init_file = File.join(oracle_home_dir, 'database', "init#{container_instance_name}.ora")
        container_sp_file = File.join(oracle_home_dir, 'database', "spfile#{container_instance_name}.ora")
        container_lk_file = File.join(oracle_home_dir, 'database', "lk#{container_instance_name}")
        container_pw_file = File.join(oracle_home_dir, 'database', "orapw#{container_instance_name}.ora")

        # remove the container service first
        remove_cdb_service(container_name)
      end
      Puppet.debug("Removing container init file #{container_init_file}")
      if File.exist?(container_init_file)
        Puppet.debug("Removing container init #{container_init_file}")
        File.delete(container_init_file)
      end
      if File.exist?(container_sp_file)
        Puppet.debug("Removing container spfile #{container_sp_file}")
        File.delete(container_sp_file)
      end
      if File.exist?(container_lk_file)
        Puppet.debug("Removing container lkfile #{container_lk_file}")
        File.delete(container_lk_file)
      end
      if File.exist?(container_pw_file)
        Puppet.debug("Removing container password file #{container_pw_file}")
        File.delete(container_pw_file)
      end
    else
      fail("Error shutting down container database: #{container_name}")
    end
  end

  def change_db_admin_pwd(container_name)
    if not container_name || container_name.length == 0
      fail("It is not possible to do change password without knowing container name")
    else
      oracle_home_dir = resource[:oracle_home_dir]
      db_admin_user = 'system'
      db_admin_user2 = 'sys'
      db_admin_pwd = resource[:db_admin_pwd]
      oracle_user = resource[:oracle_user]
      rand_num = rand(1000)
      temp_dir_name = Dir.tmpdir
      change_admin_sql_path = File.join(temp_dir_name, "change_admin_pwd_#{rand_num}.sql")
      change_admin_sql = File.open(change_admin_sql_path, 'w')
      change_admin_sql.puts("ALTER USER #{db_admin_user} IDENTIFIED BY \"#{db_admin_pwd}\" container=all;")
      change_admin_sql.puts("ALTER USER #{db_admin_user2} IDENTIFIED BY \"#{db_admin_pwd}\" container=all;")
      change_admin_sql.close
      File.chmod(0755, change_admin_sql_path)
      ## Commenting the below line w.r.t. Bug 24396973 PASSWORDS VISIBLE IN DB/LINUX MT PUPPET APPLY LOGS
      #Puppet.debug(File.read(change_admin_sql_path))
      sql_output = execute_sql_command_file(oracle_home_dir, container_name, change_admin_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error caused while changing password")
      else
        Puppet.notice "Passwords for #{db_admin_user} and #{db_admin_user2} successfully changed"
      end

    end
  end

  def change_db_access_pwd(container_name)
    if not container_name || container_name.length == 0
      fail("It is not possible to do Lock password without knowing container name")
    else
      oracle_home_dir = resource[:oracle_home_dir]
      oracle_user = resource[:oracle_user]
      temp_dir_name = Dir.tmpdir
      database_name = resource[:database_name]
      db_admin_pwd = resource[:db_admin_pwd]
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

      sql_output = execute_sql_command_file(oracle_home_dir, container_name, access_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error getting acess id database: #{database_name}")
      end
      access_id = sql_output.strip
      Puppet.debug("Access id of the database: #{access_id}")

      sql_path = File.join(temp_dir_name, "access-change-#{rand_num}.sql")
      sql_qry = File.open(sql_path, 'w')

      sql_qry.puts("SET HEADING OFF;")
      sql_qry.puts("SET FEEDBACK OFF;")
      sql_qry.puts("ALTER SESSION SET CONTAINER = #{database_name};")
      sql_qry.puts("ALTER USER #{access_id} IDENTIFIED BY \"#{db_access_pwd}\";")
      sql_qry.close
      File.chmod(0755, sql_path)
      sql_output = execute_sql_command_file(oracle_home_dir, container_name, sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error While Running Qry: #{database_name}")
      else
        Puppet.notice "successfully altered the user password for #{access_id} in DB "
      end
    end
  end

  def lock_db_ps_users(container_name)
    if not container_name || container_name.length == 0
      fail("It is not possible to do Lock password without knowing container name")
    else
      oracle_home_dir = resource[:oracle_home_dir]
      oracle_user = resource[:oracle_user]
      temp_dir_name = Dir.tmpdir
      database_name = resource[:database_name]
      db_admin_pwd = resource[:db_admin_pwd]

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

      sql_output = execute_sql_command_file(oracle_home_dir, container_name, access_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error getting acess id database: #{database_name}")
      end
      access_id = sql_output.strip
      Puppet.debug("Access id of the database: #{access_id}")

      #Get all the required User Ids
      rand_num = rand(1000)
      access_sql_path = File.join(temp_dir_name, "access-#{rand_num}.sql")
      access_sql = File.open(access_sql_path, 'w')
      access_sql.puts("SET HEADING OFF;")
      access_sql.puts("SET FEEDBACK OFF;")
      access_sql.puts("ALTER SESSION SET CONTAINER = #{database_name};")
      access_sql.puts("select USERNAME from dba_users where ORACLE_MAINTAINED = 'N';")
      access_sql.close
      File.chmod(0755, access_sql_path)
      Puppet.debug(File.read(access_sql_path))

      sql_output = execute_sql_command_file(oracle_home_dir, container_name, access_sql_path, oracle_user)
      user_names = sql_output.strip
      if sql_output.include?('ERROR')
        fail("Error getting acess id database: #{database_name}")
      else
        Puppet.notice "successfully captured the user details from #{database_name }"
      end

      # Lcoking the Db PS Users
      rand_num = rand(1000)
      lock_users_sql_path = File.join(temp_dir_name, "lock_db_ps_#{rand_num}.sql")
      lock_users_sql = File.open(lock_users_sql_path, 'w')
      lock_users_sql.puts("ALTER SESSION SET CONTAINER = #{database_name};")
      user_names.each { |user_name|
        user_name = user_name.strip
        lock_users_sql.puts("ALTER USER #{user_name} ACCOUNT LOCK;")
        Puppet.notice "Locking the users#{user_name} in the DB"
      }
      lock_users_sql.close

      File.chmod(0755, lock_users_sql_path)
      Puppet.debug(File.read(lock_users_sql_path))
      sql_output = execute_sql_command_file(oracle_home_dir, container_name, lock_users_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error caused while Locking Users")
      else
        Puppet.notice "successfully Locked the users in the DB #{database_name}"
      end

      # # Lcoking the Db PS OperIds
      # rand_num = rand(1000)
      # lock_ps_opr_sql_path = File.join(temp_dir_name, "lock_db_ps_#{rand_num}.sql")
      # lock_ps_opr_sql = File.open(lock_ps_opr_sql_path, 'w')
      # lock_ps_opr_sql.puts("ALTER SESSION SET CONTAINER = #{database_name};")
      # lock_ps_opr_sql.puts("update #{access_id}.PSOPRDEFN set ACCTLOCK=1 where ACCTLOCK!=1;")
      # lock_ps_opr_sql.close
      #
      # File.chmod(0755, lock_ps_opr_sql_path)
      # Puppet.debug(File.read(lock_ps_opr_sql_path))
      # sql_output = execute_sql_command_file(oracle_home_dir, container_name, lock_ps_opr_sql_path, oracle_user)
      # if sql_output.include?('ERROR')
      #   fail("Error caused while locking Operation Ids")
      # else
      #   Puppet.notice "successfully locked the Oper Ids in the DB #{database_name}"
      # end
    end
  end

  def remote_login_pwd(container_name)
    oracle_home_dir = resource[:oracle_home_dir]
    db_admin_pwd = resource[:db_admin_pwd]
    oracle_user = resource[:oracle_user]
    database_name = resource[:database_name]

    # Step 1 check and create the orapw_file
    orapw_file = oracle_home_dir + '/dbs/orapw' + container_name
    orapw_file_create_cmd = "su -s /bin/bash #{oracle_user} -c \"orapwd FILE='#{orapw_file}' ENTRIES=20 password=#{db_admin_pwd}\""
    unless File.exists? orapw_file
      cur_path = ENV['PATH']
      new_path = "#{oracle_home_dir}/bin:#{cur_path}"
      ENV['ORACLE_HOME'] = oracle_home_dir
      ENV['ORACLE_SID'] = container_name
      ENV['PATH'] = new_path
      Open3.popen3(orapw_file_create_cmd) do |stdin, out, err|
        stdin.close
        if err.read.to_s != ''
          fail("Error creating file")
        else
          Puppet.notice "orapw_file is created in the location #{new_path}"
        end
      end
    end

    # Step 2 modify the remote_login_passwordfile param in init_ora_file
    init_ora_file = oracle_home_dir + '/dbs/init' + container_name + '.ora'
    reboot = FALSE
    if File.exists? init_ora_file
      File.delete(init_ora_file)
    end
    if not File.exists? init_ora_file
      file_output = File.open(init_ora_file, "w")
      file_output.puts("spfile=#{oracle_home_dir}/dbs/spfile#{container_name}.ora")
      file_output.puts("remote_login_passwordfile='EXCLUSIVE'")
      file_output.close
      reboot = TRUE
      File.chmod(0755, init_ora_file)
      Puppet.notice "remote login file is created in the location #{init_ora_file}"
    elsif not File.read(init_ora_file).include? "remote_login_passwordfile='EXCLUSIVE'"
      file_input = File.open(init_ora_file, "r+")
      lines = file_input.readlines
      file_input.close

      if lines.to_s.include? 'remote_login_passwordfile'
        lines.map! { |line| line.gsub(/(remote_login_passwordfile.*)/i, '')}
      end
      lines += ["remote_login_passwordfile='EXCLUSIVE'"]
      file_output = File.new(init_ora_file, "w")
      lines.each { |line| file_output.write line }
      file_output.close
      reboot = TRUE
      Puppet.notice "remote_login_passwordfile is set to exclusive in #{init_ora_file}"
    end

    # Step 3 Restarting is kept optional.
    if reboot == TRUE
      Puppet.notice 'Rebooting the Database to accept the remote password profile and access permission'
      rand_num = rand(1000)
      temp_dir_name = Dir.tmpdir
      remote_login_pwd_sql_path = File.join(temp_dir_name, "remote_login_pwd_#{rand_num}.sql")
      remote_login_pwd_sql = File.open(remote_login_pwd_sql_path, 'w')
      remote_login_pwd_sql.puts("SHUTDOWN IMMEDIATE;")
      remote_login_pwd_sql.puts("startup pfile = '#{init_ora_file}';")
      remote_login_pwd_sql.close
      File.chmod(0755, remote_login_pwd_sql_path)
      Puppet.debug(File.read(remote_login_pwd_sql_path))
      sql_output = execute_sql_command_file(oracle_home_dir, container_name, remote_login_pwd_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error Restarting DB")
      else
        Puppet.notice "Reboot of the DB #{container_name} is successful"
      end
      sleep(10)
      reopenpdb_sql_path = File.join(temp_dir_name, "reopenpdb_#{rand_num}.sql")
      reopenpdb_sql = File.open(reopenpdb_sql_path, 'w')
      reopenpdb_sql.puts("ALTER PLUGGABLE DATABASE #{database_name} CLOSE;")
      reopenpdb_sql.puts("ALTER PLUGGABLE DATABASE #{database_name} OPEN;")
      reopenpdb_sql.puts("ALTER PLUGGABLE DATABASE #{database_name} SAVE STATE;")
      reopenpdb_sql.close
      File.chmod(0755, reopenpdb_sql_path)
      Puppet.debug(File.read(reopenpdb_sql_path))
      sql_output = execute_sql_command_file(oracle_home_dir, container_name, reopenpdb_sql_path, oracle_user)
      if sql_output.include?('ERROR')
        fail("Error while connect disconnect PDB to solve restricted mode")
      else
        Puppet.notice "Restarting of the PDB is successful"
      end
    end
  end

  # TODO Will be removed, Adding as its failing temporly
  def sql_command_file(content)
    Puppet.debug("SQL Script content: #{content}")
    temp_dir_name = Dir.tmpdir()
    rand_num = rand(1000)
    command_file_path = File.join(temp_dir_name, "sql-cmd_#{rand_num}.sql")
    command_file = File.open(command_file_path, 'w')

    if Facter.value(:osfamily) == 'windows'
      #perm_cmd = "icacls #{command_file_path} /grant Administrators:F /T > NUL"
      perm_cmd = "icacls #{command_file_path} /grant *S-1-5-32-544:F /T > NUL"
      system(perm_cmd)
    else
      FileUtils.chmod(0755, command_file_path)
    end
    command_file.write(content)
    command_file.close
    return command_file_path
  end
end
