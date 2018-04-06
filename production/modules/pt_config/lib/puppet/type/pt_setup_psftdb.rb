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

require 'pathname'
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent)
$:.unshift(Pathname.new(__FILE__).dirname.parent.parent.parent.parent + 'easy_type' + 'lib')

require 'fileutils'
require 'easy_type'
require 'pt_comp_utils/validations'
require 'puppet/parameter/boolean'

module Puppet
  Type.newtype(:pt_setup_psftdb) do
    include EasyType
    include ::PtCompUtils::Validations

    @doc = "Manages the state of PeopleSoft database"

    validate do
      # make sure the oracle user and group is specified, if the os family
      # is not windows
      if Facter.value(:osfamily) != 'windows'
        oracle_user = self[:oracle_user]
        oracle_user_group = self[:oracle_user_group]
        validate_oracle_user_and_group(oracle_user, oracle_user_group)
      end

      database_dir = self[:database_dir]
      if database_dir.nil?
        fail("database_dir attribute should be specified")
      end

      oracle_home_dir = self[:oracle_home_dir]
      if oracle_home_dir.nil?
        fail("oracle_home_dir attribute should be specified")
      end

      container_name = self[:container_name]
      if container_name.nil?
        fail("container_name attribute should be specified")
      end

      database_name = self[:database_name]
      if database_name.nil?
        fail("database_name attribute should be specified")
      end

      if self[:ensure] == :present
        if self[:new_container] == true and self[:cold_backup_container] == true
          # ensure that the container backup file is specified
          container_backup_file = self[:container_backup_file]
          if container_backup_file.nil?
            fail("container cold-backup zip _file attribute should be specified.")
          end
          unless Puppet::Util.absolute_path?(container_backup_file)
            fail Puppet::Error, "container cold-backup file must be fully qualified, not '#{container_backup_file}'"
          end
        end
        if self[:new_container] == true and self[:cold_backup_container] == false
          # ensure that the container settings are specified
          if self[:container_settings].nil? || self[:container_settings].size == 0
            fail("container_settings attribute should be specified for creating a container.")
          end
        end
        # make sure connect information is provided
        db_connect_id = self[:db_connect_id]
        if db_connect_id.nil?
          fail("db_connect_id attribute should be specified")
        end

        db_connect_pwd = self[:db_connect_pwd]
        if db_connect_pwd.nil?
          fail("db_connect_pwd attribute should be specified")
        end
      end
    end

    ensurable

    newparam(:new_container, :boolean => true, :parent => Puppet::Parameter::Boolean) do

      desc "flag that denotes whether to create a new container or not"

      defaultto true
    end

    newparam(:cold_backup_container, :boolean => true, :parent => Puppet::Parameter::Boolean) do

      desc "flag that denotes whether the new container is created using a cold backup"

      defaultto true
    end

    newparam(:container_backup_file) do
      desc "The zip file containing the coldback of a container. If cold_back_container
        flag is set to 'true', this zip file is used to create the container."
    end

    newparam(:container_name) do
      desc "Specify the name of the container database"

      validate do |value|
        if value.match(/^[A-Z][A-Za-z0-9]{0,7}$/).nil?
          fail("Container instance name must be at most 8 " +
               "alphanumeric characters with first character an " +
               "Uppercase alphabet.")
        end
      end
    end

    newparam(:container_instance_name) do
      desc "Specify the name of the container instance database, Only applicable when rac_database is 'true'"
    end

    newparam(:scan_name) do
      desc "Specify the Single Client Access Name, Only applicable when rac_database is 'true'"
    end

    newparam(:container_settings, :array_matching => :all) do
      desc "Specifies a list of container settings to be applied to the
           container database created"

      validate do |values|
        values = [values] unless values.is_a? Array
        values.each do |item|
          if item.split('=')[1].nil?
            raise ArgumentError, "Key/value pairs must be separated by an ="
          elsif ['pwd', 'pass'].any? {|var| item.downcase.split('=')[0].include? var}
            Puppet.debug("Got item: #{item.gsub(item.split('=')[1], '****')}")
          else
            Puppet.debug("Got item: #{item}")
          end
        end

        # convert the array into hash for easy validations
        values_hash = Hash.new do |h,k|
          fail("#{k} needs to be specified in the container_settings parameter")
        end
        temp_hash = {}
        values.each do |item|
          temp_hash[item.split('=')[0].strip.to_sym]=item.split('=')[1].strip
        end
        values_hash.update(temp_hash)

        # validate to make sure all the required parameters are specified in
        # the array
        key_nls_length_semantics = :nls_length_semantics
        key_nls_charset          = :nls_characterset
        key_nls_nchar_charset    = :nls_nchar_characterset

        nls_semantics = values_hash[key_nls_length_semantics]
        values_hash[key_nls_charset]
        values_hash[key_nls_nchar_charset]

        # validate the nls length sematics type
        valid_semantics_list = [ 'CHAR', 'BYTE' ]
        if ! valid_semantics_list.include?(nls_semantics.upcase)
          fail("Specified NLS LENGTH SEMANTICS '#{nls_semantics}' is not a valid value; " + \
               "valid values are: #{valid_semantics_list.inspect}")
        end
      end

      munge do |values|
        container_hash = {}

        values = [values] unless values.is_a? Array
        values.each do |value|
          container_hash[value.split('=')[0].strip.to_sym]=value.split('=')[1].strip
        end
        if provider.respond_to?(:container_hash=)
          provider.container_hash=(container_hash)
        end
        return container_hash
      end
    end

    newparam(:database_name, :namevar => true) do
      desc "Specify the name of the database instance"

      validate do |value|
        Puppet.debug("Validating database name: #{value}")
        if value.match(/^[A-Z][A-Za-z0-9]{0,7}$/).nil?
          fail("Database instance name must be at most 8 " +
               "alphanumeric characters with first character an " +
               "Uppercase alphabet.")
        end
      end
    end

    newparam(:database_dir) do
      desc "Specify the directory where the database files reside"

    end

    newparam(:oracle_user) do
      desc "* Unix Only * The OS user who is the owner of the database files"

    end

    newparam(:oracle_user_group) do
      desc "* Unix Only * The OS group that the oracle user belongs to."
    end

    newparam(:db_connect_id) do
      desc "The connect ID of the database"

      validate do |value|
        if value.match(/^[A-Za-z0-9]{0,8}$/).nil?
          fail("Connect id must be at most 8 alphanumeric characters.")
        end
      end
    end

    newparam(:db_connect_pwd) do
      desc "The password that is associated with the connect ID"
    end

    newparam(:oracle_home_dir) do
      desc "Specify the directory where Oracle is installed"

      validate do |value|
        unless Puppet::Util.absolute_path?(value)
          fail Puppet::Error, "Oracle Home path must be fully qualified, not '#{value}'"
        end
      end
    end

    newparam(:rac_database, :boolean => true, :parent => Puppet::Parameter::Boolean) do

      desc "flag that denotes whether the database is a RaC database"

      defaultto false
    end

    newparam(:db_access_pwd) do
      desc "The password used for accessing the peoplesoft DB"
    end

    parameter :recreate
    newproperty(:db_admin_pwd) do
      desc "The password used for administring the DB"
    end
  end
end
