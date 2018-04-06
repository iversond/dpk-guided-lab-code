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

Puppet::Type.type(:pt_ulimit_entry).provide :ulimit_entry do

  defaultfor :kernel => :Linux
  confine    :kernel => :Linux

  def initialize(value={})
    super(value)
    Puppet.debug("Ulimit entry Provider Initialization")

    @ulimit_config_file = '/etc/security/limits.conf'
    @property_flush = {}
  end

  mk_resource_methods

  def ulimit_value=(value)
    @property_flush[:ulimit_value] = value
  end

  def exists?
    if ! @property_hash[:ensure].nil?
      return @property_hash[:ensure] == :present
    end
    ulimit_entry_exists = check_ulimit_entry_exists?()
    if ulimit_entry_exists == true
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
    domain = resource[:ulimit_domain]
    type = resource[:ulimit_type].to_s
    item = resource[:ulimit_item].to_s
    value = resource[:ulimit_value].to_s

    ulimit_entry = "#{domain}   #{type}   #{item}   #{value}"
    Puppet.debug("Creating ulimit entry #{ulimit_entry}")
    File.open(@ulimit_config_file, 'a') { |f| f.puts(ulimit_entry)}

    @property_hash[:ensure] = :present
    @property_flush.clear
  end

  def destroy
    domain = resource[:ulimit_domain]
    type = resource[:ulimit_type].to_s
    item = resource[:ulimit_item].to_s

    ulimit_entry = "#{domain}.*#{type}.*#{item}"
    ulimit_entry_re = Regexp.new ulimit_entry
    Puppet.debug("Removing ulimit entry #{ulimit_entry}")

    file_content_mod = File.readlines(@ulimit_config_file).reject {
      |line| line =~ ulimit_entry_re
    }
    File.open(@ulimit_config_file, "w") { |file| file << file_content_mod }
    @property_hash[:ensure] = :absent
    @property_flush.clear

  end

  def flush
    if @property_flush.size == 0
      Puppet.debug("Nothing to flush")
      return
    end
    domain = resource[:ulimit_domain]
    type = resource[:ulimit_type].to_s
    item = resource[:ulimit_item].to_s
    value = @property_flush[:ulimit_value]

    ulimit_entry = "#{ulimit_domain}.*#{ulimit_type}.*#{ulimit_item}"
    ulimit_entry_re = Regexp.new ulimit_entry

    ulimit_entry_mod = "#{domain}   #{type}   #{item}   #{value}"
    file_content_orig = File.read(@ulimit_config_file)
    file_content_mod = file_content_orig.gsub(ulimit_entry_re,
                                              ulimit_entry_mod)
    File.open(@ulimit_config_file, "w") { |file| file << file_content_mod }

    @property_hash = resource.to_hash
    @property_flush.clear
  end

  def self.instances
    []
  end

  private

  def check_ulimit_entry_exists?

    domain = resource[:ulimit_domain]
    type = resource[:ulimit_type].to_s
    item = resource[:ulimit_item].to_s

    ulimit_entry = "^#{domain}.*#{type}.*#{item}"
    ulimit_entry_re = Regexp.new ulimit_entry

    Puppet.debug("Checking if ulimit entry #{ulimit_entry} exists")

    ulimit_entry_exists = false
    if File.readlines(@ulimit_config_file).grep(ulimit_entry_re).any?
      ulimit_entry_exists = true
    end
    return ulimit_entry_exists
  end
end
