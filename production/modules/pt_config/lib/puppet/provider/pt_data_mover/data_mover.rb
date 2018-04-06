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

require 'puppet/provider/pt_utils'

# Puppet::Type.type(:pt_data_mover).provide :data_mover do
class Puppet::Provider::Datamover < Puppet::Provider
  @dms_script_file = nil
  # mk_resource_methods

   def run_dms_script(dms_location, db_access_id=nil)

     @dms_script_file = dms_location
     Puppet.debug("Phase one property file: #{@dms_script_file}")

     output, status = run_psdmt(@dms_script_file, db_access_id)

     if File.exist?(@dms_script_file)
       Puppet.debug("Data Mover Script file #{@dms_script_file} is present")
     else
       Puppet.debug("Data Mover Script file #{@dms_script_file} is absent")
     end
     Puppet.debug("Removing Data Mover Script #{@dms_script_file}")
     if status != 0
       Puppet.debug("DMS run failed: #{output}")
     end
     FileUtils.remove_file(@dms_script_file, :force => true)
     return output, status
   end

   private

    def create_dms_cmd_file(dms_parameters)
      # genenrate the DMS file
      temp_dir_name = Dir.tmpdir
      rand_num = rand(1000)
      file_prop_path = File.join(temp_dir_name, "temp_dms_#{rand_num}.txt")
      file_prop = File.open(file_prop_path, 'w')
      file_prop.puts dms_parameters
      file_prop.close
      File.chmod(0755, file_prop_path)
      return file_prop_path
    end

   def create_dms_script(dms_content_array)
      # genenrate the properties file
     temp_dir_name = Dir.tmpdir
     rand_num = rand(1000)
     file_prop_path = File.join(temp_dir_name, "temp_dms_#{rand_num}.dms")
     file_prop = File.open(file_prop_path, 'w')
     dms_content_array.each { |dms_line|
       file_prop.puts dms_line
     }
     file_prop.close
     File.chmod(0755, file_prop_path)
     return file_prop_path
   end

   def run_psdmt(dms_file, db_access_id=nil)
     Puppet.debug('Executing the Data Mover File - dms_file')
     output      = ''
     exit_status = 0

     db_type     = resource[:db_type]
     if db_type == 'MSSQL'
       db_type = 'MICROSFT'
     end

     case Facter.value(:osfamily)
     when 'windows'
       insert_quote = ''
       dms_cmd_prefix = "cmd /c"
       dms_cmd = File.join(resource[:ps_home],'bin', 'client', 'winx86', 'psdmtx.exe')
       set_user_env
     when 'AIX'
       insert_quote = "\""
       dms_cmd_prefix = "su - #{resource[:os_user]} -c #{insert_quote} "
       dms_cmd = File.join(resource[:ps_home], 'bin', 'psdmtx')
     when 'Solaris'
       insert_quote = "\""
       dms_cmd_prefix = "su - #{resource[:os_user]} -c #{insert_quote} "
       dms_cmd = File.join(resource[:ps_home], 'bin', 'psdmtx')
     else
       insert_quote = "\""
       dms_cmd_prefix = "su -s /bin/bash - #{resource[:os_user]} -c #{insert_quote} "
       dms_cmd = File.join(resource[:ps_home], 'bin', 'psdmtx')
     end

     db_name        = resource[:db_name]
     if db_access_id == nil?
       db_access_id   = resource[:db_access_id]
     end
     db_access_pwd  = resource[:db_access_pwd]
     db_server_name = resource[:db_server_name]

     db_connect_id  = resource[:db_connect_id]
     db_connect_pwd = resource[:db_connect_pwd]

     dms_args = "-CT #{db_type} -CD #{db_name} -CO #{db_access_id} -CP #{db_access_pwd} -CI #{db_connect_id} -CW #{db_connect_pwd} -FP #{dms_file}"

     unless db_server_name.nil?
       dms_args << " -CS #{db_server_name}"
     end

     # dms_full_cmd = "#{dms_cmd_prefix} #{dms_cmd} #{dms_args} #{insert_quote}"
     dms_cmd_file = create_dms_cmd_file(dms_args)
     dms_full_cmd = "#{dms_cmd_prefix} #{dms_cmd} #{dms_cmd_file} #{insert_quote}"

     Puppet.debug("PSDMT Command: #{dms_full_cmd}")
     begin
       if Facter.value(:osfamily) == 'windows'
         output = execute_command(dms_full_cmd, {}, true)
       else
         output = Puppet::Util::Execution.execute(dms_full_cmd, :failonfail => true, :combine => true)
       end
       if output.include?('STATUS: ERROR') || output.include?('failed: No such file or directory')
         exit_status = 1
       end

      rescue Puppet::ExecutionFailure => e
        exit_status = 1
        output = "#{output}, #{e.message}"
      ensure
      end
      FileUtils.remove_file(dms_cmd_file, :force => true)
      return output, exit_status
   end
end

