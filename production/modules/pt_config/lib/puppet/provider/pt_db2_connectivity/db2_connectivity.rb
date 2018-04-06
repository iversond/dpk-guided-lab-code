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
require 'tmpdir'
require 'fileutils'
require 'etc'

Puppet::Type.type(:pt_db2_connectivity).provide :db2_connectivity do
  include EasyType::Template

  desc "The DB2 connectivity provider that catalogs/uncatalogs
       databases and nodes for both DB2 LUW & DB2 z/OS"

  mk_resource_methods

  def self.instances
    []
  end

  has_feature :ensurable

  def catalog
    Puppet.debug("Action catalog called")

    # make sure the db2_host is given
    if resource[:db2_host].nil?
      raise ArgumentError, "DB2 database host needs to be " +
                           "specified for cataloging a node."
    end
    # make sure the db2_port is given
    if resource[:db2_port].nil?
      raise ArgumentError, "DB2 database port needs to be " +
                           "specified for cataloging a node."
    end
    db2_type                 = resource[:db2_type]
    db2_node                 = resource[:db2_node]
    db2_database_name        = resource[:db_name]
    db2_target_database_name = resource[:db2_target_db]

    ps_home_dir              = resource[:ps_home_dir]
    db2_sqllib_dir           = resource[:db2_sqllib_dir]
    db2_user_name            = resource[:db2_user_name]
    db2_user_pwd             = resource[:db2_user_pwd]

    # uncatalog first if database and node are already cataloged
    uncatalog

    catalog_node(db2_type, db2_node)
    catalog_database(db2_type, db2_node, db2_database_name, db2_target_database_name)
    bind_database(db2_type, ps_home_dir, db2_sqllib_dir, db2_database_name, db2_user_name, db2_user_pwd)
  end

  def uncatalog
    Puppet.debug("Action uncatalog called")
    #

    if Facter.value(:osfamily) != 'windows'
      # make sure the db2_instance_user is given
      db2_instance_user = resource[:db2_instance_user]
      if db2_instance_user.nil?
        raise ArgumentError, "DB2 instance user needs to be " +
                             "specified for uncataloging a node on Unix platform."
      end
      # check if the user is present or not
      begin
        Etc.getpwnam(db2_instance_user)
      rescue ArgumentError
        Puppet.debug("Instance User #{db2_instance_user} not present, nothing to uncatalog")
        return
      end
    end
    db2_type = resource[:db2_type]
    db2_node = resource[:db2_node]
    db2_database_name = resource[:db_name]

    if is_database_cataloged?(db2_database_name)
      Puppet.debug("DB2 database #{db2_database_name} is already cataloged")
      uncatalog_database(db2_type, db2_database_name)
    end

    if is_node_cataloged?(db2_node)
      Puppet.debug("DB2 node #{db2_node} is already cataloged")
      uncatalog_node(db2_node)
    end
  end

  private

  def is_node_cataloged?(db2_node)

    Puppet.debug("Checking if node #{db2_node} is cataloged")

    node_cataloged = false

    if Facter.value(:osfamily) != 'windows'
      instance_user = resource[:db2_instance_user]
      if Facter.value(:osfamily) == 'Solaris' or  Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
         list_node_cmd = "su - #{instance_user} -c \"db2 list node DIRECTORY\""
      else
         list_node_cmd = "su -s /bin/bash - #{instance_user} -c \"db2 list node DIRECTORY\""
      end
    else
      list_node_cmd = "cmd.exe /C \"set DB2CLP=**$$** && db2 list node DIRECTORY\""
    end
    Puppet.debug("DB2 list node command: #{list_node_cmd}")

    begin
      command_output = Puppet::Util::Execution.execute(list_node_cmd, :failonfail => true, :combine => true)
      Puppet.debug("DB2 catalog list node successful: #{command_output}")

      if command_output.include?(db2_node)
        node_cataloged = true
      end

    rescue Puppet::ExecutionFailure => e
      if e.message.include?("The node directory cannot be found") == false and
         e.message.include?("The node directory is empty") == false and
         e.message.include?("db2: command not found") == false
      	raise Puppet::Error, "DB2 list node failed: #{e.message}"
      end
    end
    return node_cataloged
  end

  def is_database_cataloged?(db2_database_name)
    Puppet.debug("Checking if DB2 database #{db2_database_name} is cataloged")

    database_cataloged = false

    if Facter.value(:osfamily) != 'windows'
      instance_user = resource[:db2_instance_user]
      if Facter.value(:osfamily) == 'Solaris' or  Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
         list_database_cmd = "su - #{instance_user} -c \"db2 list database DIRECTORY\""
      else
         list_database_cmd = "su -s /bin/bash - #{instance_user} -c \"db2 list database DIRECTORY\""
      end
    else
      list_database_cmd = "cmd.exe /C \"set DB2CLP=**$$** && db2 list database DIRECTORY\""
    end

    begin
      command_output = Puppet::Util::Execution.execute(list_database_cmd, :failonfail => true, :combine => true)
      Puppet.debug("DB2 list database successful: #{command_output}")

      if command_output.include?(db2_database_name)
        database_cataloged = true
      end

    rescue Puppet::ExecutionFailure => e
      if e.message.include?("The database directory cannot be found on the indicated file system") == false and
         e.message.include?("The system database directory is empty") == false and
         e.message.include?("db2: command not found") == false
      	raise Puppet::Error, "DB2 list database failed: #{e.message}"
      end
    end
    return database_cataloged
  end

  def catalog_node(db2_type, db2_node)
    db2_host = resource[:db2_host]
    db2_port = resource[:db2_port]
    db2_type = db2_type.to_s.upcase

    if Facter.value(:osfamily) != 'windows'
      execute_db2_script("catalog_node.sh.erb", db2_type, db2_node, "", "", db2_host, db2_port)
    else
      execute_db2_script("catalog_node.bat.erb", db2_type, db2_node, "", "", db2_host, db2_port)
    end
  end

  def catalog_database(db2_type, db2_node, db2_database_name, db2_target_database_name)
    db2_type = db2_type.to_s.upcase

    if Facter.value(:osfamily) != 'windows'
      execute_db2_script("catalog_database.sh.erb", db2_type, db2_node, db2_database_name, db2_target_database_name)
    else
      execute_db2_script("catalog_database.bat.erb", db2_type, db2_node, db2_database_name, db2_target_database_name)
    end
  end

  def uncatalog_node(db2_node)
    if Facter.value(:osfamily) != 'windows'
      execute_db2_script("uncatalog_node.sh.erb", "", db2_node)
    else
      execute_db2_script("uncatalog_node.bat.erb", "", db2_node)
    end
  end

  def uncatalog_database(db2_type, db2_database_name)
    db2_type = db2_type.to_s.upcase

    if Facter.value(:osfamily) != 'windows'
      execute_db2_script("uncatalog_database.sh.erb", db2_type, "", db2_database_name)
    else
      execute_db2_script("uncatalog_database.bat.erb", db2_type, "", db2_database_name)
    end
  end

  def bind_database(db2_type, ps_home_dir, db2_sqllib_dir, db2_database_name, db2_user_name, db2_user_pwd)
    # determine if the database is unicode or not
    unicode_db=1
    pt_prop_hash = {}
    pt_prop_file = File.open("#{ps_home_dir}/peopletools.properties")
    pt_prop_file.each_line {|item|
      item_key = item.split('=')[0]
      item_val = item.split('=')[1]
      if item_val.nil? == false
        pt_prop_hash[item.split('=')[0]] = item_val.chomp
      end
    }
    pt_prop_file.close()
    unicode_db_key = 'unicodedb'
    unicode_db_val = pt_prop_hash[unicode_db_key]
    if unicode_db_val.nil?
      Puppet.debug("Unable to determine the unicode db value from peopletools.properties file")
    else
      unicode_db = unicode_db_val.to_i
    end
    Puppet.debug("Retrieved unicode db value from peopletools.properties file is #{unicode_db.to_s}")

    if Facter.value(:osfamily) != 'windows'
      db2_script_content = template("puppet:///modules/pt_config/pt_db2_setup/bind_database.sh.erb",
                                   binding)
    else
      ps_home_dir = ps_home_dir.gsub('/', '\\')
      db2_script_content = template("puppet:///modules/pt_config/pt_db2_setup/bind_database.bat.erb",
                                   binding)
    end
    execute_db2_script_content(db2_script_content)
  end

  def execute_db2_script(db2_script_erb, db2_type, db2_node, db2_database_name = "",
                         db2_target_database_name = "", db2_host = "", db2_port = "")
    db2_script_content = template("puppet:///modules/pt_config/pt_db2_setup/#{db2_script_erb}",
                                   binding)
    execute_db2_script_content(db2_script_content)
  end

  def execute_db2_script_content(db2_script_content)

    temp_dir_name = Dir.tmpdir()
    rand_num = rand(1000)
    if Facter.value(:osfamily) != 'windows'
      file_ext = '.sh'
    else
      file_ext = '.bat'
    end
    db2_script = File.join(temp_dir_name, "db2_cmds-#{rand_num}#{file_ext}")
    File.open(db2_script, 'w') { |f| f.write(db2_script_content) }
    FileUtils.chmod(0755, db2_script)

    if Facter.value(:osfamily) != 'windows'
      instance_user = resource[:db2_instance_user]
      if Facter.value(:osfamily) == 'Solaris' or  Facter.value(:osfamily) == 'AIX' or Facter.value(:osfamily) == 'HP-UX'
         db2_cmd = "su - #{instance_user} -c \"sh #{db2_script}\""
      else
         db2_cmd = "su -s /bin/bash - #{instance_user} -c \"sh #{db2_script}\""
      end
    else

      db2_cmd = "cmd.exe /C #{db2_script}"
    end
    Puppet.debug("DB2 script: #{db2_script_content}")

    begin
      if Facter.value(:osfamily) != 'windows'
        Puppet::Util::Execution.execute(db2_cmd, :failonfail => true, :combine => true)
        Puppet.debug("DB2 script executed successfully")
      else
        ret_code = system(db2_cmd)
      end

    rescue Puppet::ExecutionFailure => e
    	raise Puppet::Error, "DB2 script execution failed: #{e.message}"
    ensure
      FileUtils.remove_file(db2_script, :force => true)
    end
  end
end
