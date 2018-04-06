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

require 'fileutils'
require 'etc'
require 'rexml/document'
require 'puppet/provider/deployarchive'

Puppet::Type.type(:pt_deploy_psftdb).provide :deploy_psftdb,
                  :parent => Puppet::Provider::DeployArchive do

  if Facter.value(:osfamily) != 'windows'
    commands :extract_cmd =>  'tar'
  end

  mk_resource_methods

  def destroy
    pre_delete()

    deploy_location = resource[:deploy_location]
    FileUtils.rm_rf(deploy_location)

    post_delete()
    @property_hash[:ensure] = :absent
  end

  def post_create()
    database_name = resource[:database_name]
    deploy_location = resource[:deploy_location]

    if Facter.value(:osfamily) != 'windows'
      deploy_user = resource[:deploy_user]
      deploy_group = resource[:deploy_user_group]

      psft_db_base = File.dirname(deploy_location)
      # change the oracle base ownership
      user_id = Etc.getpwnam(deploy_user).uid
      group_id = Etc.getgrnam(deploy_group).gid

      FileUtils.chown(user_id, group_id, psft_db_base)
      FileUtils.chmod(0755, psft_db_base)
    end
    # rename the database xml file to match the database
    pdb_xml_file = Dir.glob(File.join(deploy_location, '*.xml'))[0]

    pdb_new_xml_file = File.join(deploy_location, "#{database_name}.xml")
    if Facter.value(:osfamily) == 'windows'
      pdb_new_xml_file = pdb_new_xml_file.gsub('/', '\\')
    end

    if pdb_xml_file != pdb_new_xml_file
      FileUtils.mv(pdb_xml_file, pdb_new_xml_file)
    end
    file = File.new(pdb_new_xml_file)
    doc = REXML::Document.new file
    doc.elements.each("PDB/tablespace/file/path") do |elem|
      text = elem.text()
      basename = File.basename(text)

      db_file_location = File.join(deploy_location, basename)
      if Facter.value(:osfamily) == 'windows'
        db_file_location = db_file_location.gsub('/', '\\')
      end
      elem.text = db_file_location
    end
    file.close
    File.open(pdb_new_xml_file, "w") { |file| file << doc }
  end
end
