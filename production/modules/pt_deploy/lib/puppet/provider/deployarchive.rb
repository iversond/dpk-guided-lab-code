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

require 'puppet/provider'
require 'fileutils'
require 'etc'
require 'tempfile'
require 'tmpdir'

require 'pt_deploy_utils/validations'

if Facter.value(:osfamily) == 'windows'
  require 'zlib'
  require 'archive/tar/minitar'
  include Archive::Tar
end

class Puppet::Provider::DeployArchive < Puppet::Provider
  include ::PtDeployUtils::Validations

  def exists?
    # check if redeploy is specified
    if resource[:ensure] == :present and resource[:redeploy] == true
      Puppet.debug("Recreate set to true")
      destroy()
    end
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end

    deploy_location = resource[:deploy_location]
    if FileTest.directory?(deploy_location) and
      Dir.glob(File.join(deploy_location, '*')).empty? == false
      @property_hash[:ensure] = :present
      Puppet.debug("Resource exists")
      true
    else
      @property_hash[:ensure] = :absent
      Puppet.debug("Resource does not exists")
      false
    end
  end

  def create
    validate_parameters()
    pre_create()
    post_create()
    @property_hash[:ensure] = :present
  end


  def destroy

    if resource[:ensure] == :absent and resource[:remove] == false
      Puppet.debug("Remove flag set to false, component will not be removed")
      return
    end
    pre_delete()

    deploy_location = resource[:deploy_location]
    Puppet.debug("Removing deployment location #{deploy_location}")

    if Facter.value(:osfamily) == 'windows'
      if File.exist?(deploy_location)
        deploy_location = deploy_location.gsub('/', '\\')
        readonly_cmd = "attrib -R #{deploy_location} /D /S > NUL"
        system(readonly_cmd)
        if $? == 0
          Puppet.debug("Read-Only attribute of deployment location #{deploy_location} removed successfully")
        else
          Puppet.debug("Failed to remove Read-Only attribute of deploy location #{deploy_location}")
        end
        remove_cmd = "rmdir /Q /S #{deploy_location}"
        system(remove_cmd)
        if $? == 0
          Puppet.debug("Deployment location #{deploy_location} removed successfully")
        else
          Puppet.debug("Failed to remove deploy location #{deploy_location}")
        end
      end
    else
    FileUtils.rm_rf(deploy_location)
    end

    post_delete()

    @property_hash[:ensure] = :absent
  end

  def flush
    @property_hash = resource.to_hash
  end

  def self.instances
    []
  end

  def deploy_archive(archive_file, destination,
                    deploy_user, deploy_group)
    Puppet.debug("Started deployment")

    if Facter.value(:osfamily) == 'windows'
      tgz = Zlib::GzipReader.new(File.open(archive_file, 'rb'))
      Minitar.unpack(tgz, destination)
    else
      begin
        # create the destination directory
        FileUtils.makedirs(destination)

        if (Facter.value(:osfamily) == 'AIX' || Facter.value(:osfamily) == 'Solaris') 
          system("cd #{destination} && gunzip -r #{archive_file} -c | tar xf -")
        else
          extract_cmd('xzf', archive_file, '-C', destination)
        end
        change_ownership(deploy_user, deploy_group, destination)

      rescue Puppet::ExecutionFailure => e
        raise Puppet::Error, "Extraction of #{archive_file} failed: " + \
                           " #{e.message}"
      end
    end
    Puppet.debug("Ended deployment")
  end

  private

  def validate_parameters()
    # validate if the archive is given as an absolute path
    archive_file = resource[:archive_file]
    unless Puppet::Util.absolute_path?(archive_file)
      raise Puppet::Error, "Archive file must be fully qualified, not " + \
                           "'#{archive_file}'"
    end
    # validate to make sure archive file exists
    unless FileTest.exists?(archive_file)
      raise Puppet::Error, "Archive file #{archive_file} does not exists"
    end
    if Facter.value(:osfamily) != 'windows'
      deploy_user = resource[:deploy_user]
      deploy_group = resource[:deploy_user_group]

      check_user_group(deploy_user, deploy_group)
    end
  end

  def pre_create()
    archive_file = resource[:archive_file]
    deploy_location = resource[:deploy_location]
    deploy_user = resource[:deploy_user]
    deploy_group = resource[:deploy_user_group]

    Puppet.debug("Deploying archive #{archive_file} into #{deploy_location}")
    deploy_archive(archive_file, deploy_location,
                  deploy_user, deploy_group)
  end

  def change_ownership(deploy_user, deploy_group, destination)
    if Facter.value(:osfamily) != 'windows'
      user_uid = Etc.getpwnam(deploy_user).uid
      group_gid = Etc.getgrnam(deploy_group).gid

      Puppet.debug("Changing ownership of #{destination}")
      FileUtils.chown_R(user_uid, group_gid, destination)
      FileUtils.chmod_R(0755, destination)
    end
  end

  def post_create()
  end

  def pre_delete()
  end

  def post_delete()
  end

  def generate_windows_unzip_script(zip_file_name, destination)

    zip_file_name = zip_file_name.gsub('/', '\\')
    destination   = destination.gsub('/', '\\')

    temp_dir_name = Dir.tmpdir()
    extract_file_path = File.join(temp_dir_name, "zip_extract.ps1")
    extract_file = File.open(extract_file_path, 'w')

    extract_file.puts("$zip_name = (Get-ChildItem \"#{zip_file_name}\").Name")
    extract_file.puts("Try {")
    extract_file.puts("  $shell = new-object -com shell.application")
    extract_file.puts("  $zip = $shell.NameSpace(\"#{zip_file_name}\")")
    extract_file.puts("  ForEach($item in $zip.items()) {")
    extract_file.puts("    $shell.Namespace(\"#{destination}\").CopyHere($item, 0x14)")
    extract_file.puts("  }")
    extract_file.puts("  Exit 0")
    extract_file.puts("}")
    extract_file.puts("Catch {")
    extract_file.puts("  $error_message = $_.Exception.Message")
    extract_file.puts("  Write-Host $error_message")
    extract_file.puts("  Exit 1")
    extract_file.puts("}")
    extract_file.close
    File.chmod(0755, extract_file_path)
    Puppet.debug(File.read(extract_file_path))

    return extract_file_path
  end
end
