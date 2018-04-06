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

if Facter.value(:osfamily) == 'windows'
  require 'win32/registry'
  require 'win32/service'
  include Win32
end

Puppet::Type.type(:pt_deploy_jdk).provide :deploy_jdk,
                  :parent => Puppet::Provider::DeployArchive do

  if Facter.value(:osfamily) != 'windows'
    commands :extract_cmd => 'tar'
  end

  mk_resource_methods

  def post_create()
    deploy_location = resource[:deploy_location]
    if Facter.value(:osfamily) == 'windows'
      #FileUtils.chmod_R(0755, deploy_location)
      # give full control to 'Administrators'
      #  TODO: need to check why the chmod_R is not working
      #perm_cmd = "icacls #{deploy_location} /grant Administrators:F /T > NUL"
      perm_cmd = "icacls #{deploy_location} /grant *S-1-5-32-544:(OI)(CI)F /T > NUL"
      system(perm_cmd)
      if $? == 0
        Puppet.debug('JDK deploy location permissions updated successfully')
      else
        raise Puppet::Error, "JDK deploy location permissions update failed"
      end

      # prepend the JDK path to the path environment
      begin
        win_env_key = "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment"
        Win32::Registry::HKEY_LOCAL_MACHINE.open(win_env_key, Win32::Registry::KEY_ALL_ACCESS) do |reg|
          path_reg_key = "Path"
          begin
            path_value = reg[path_reg_key]
            Puppet.debug("Current PATH environment variable value: #{path_value}")

            jdk_bin_path = File.join(deploy_location, 'bin')
            jdk_bin_path = jdk_bin_path.gsub('/', '\\')
            path_value = "#{jdk_bin_path};#{path_value}"
            Puppet.debug("Modified PATH envionment variable value: #{path_value}")

            reg[path_reg_key] = path_value
          rescue
            raise Puppet::ExecutionFailure, "Failed to access environment path value in the registry"
          end
        end
      rescue
        raise Puppet::ExecutionFailure, "Failed to access environment key in the registry"
      end
    end
  end

  def post_delete()
    deploy_location = resource[:deploy_location]
    if Facter.value(:osfamily) == 'windows'
      # remove the JDK path to the path environment
      begin
        win_env_key = "SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment"
        Win32::Registry::HKEY_LOCAL_MACHINE.open(win_env_key, Win32::Registry::KEY_ALL_ACCESS) do |reg|
          path_reg_key = "Path"
          begin
            path_value = reg[path_reg_key]
            Puppet.debug("Current PATH environment variable value: #{path_value}")

            jdk_bin_path = File.join(deploy_location, 'bin')
            jdk_bin_path = jdk_bin_path.gsub('/', '\\')

            path_value = path_value.gsub(jdk_bin_path + ';', '')
            Puppet.debug("Modified PATH envionment variable value: #{path_value}")

            reg[path_reg_key] = path_value
          rescue
            raise Puppet::ExecutionFailure, "Failed to access environment path value in the registry"
          end
        end
      rescue
        raise Puppet::ExecutionFailure, "Failed to access environment key in the registry"
      end
    end
  end
end
