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

require 'easy_type'

module Puppet
  Type.newtype(:pt_db2_connectivity) do
    include EasyType

    @doc = "Catalogs or uncatalogs a database at a node for DB2 database server"

    feature :ensurable, "The provider can catalog or uncatalog the database on node",
      :methods => [:catalog, :uncatalog]

    validate do
      if self[:ps_home_dir].nil?
        fail("ps_home_dir attribute should be specified")
      end
      if self[:db2_sqllib_dir].nil?
        fail("db2_sqllib_dir attribute should be specified")
      end
      # make sure DB name is specified
      if self[:db_name].nil?
        fail("db_name should be specified for cataloging and uncatloging nodes")
      end
      # make sure the DB2 node is specified
      if self[:db2_node].nil?
        fail("db2_node should be specified for cataloging and uncataloging")
      end
    end

    # Handle whether the node should be cataloged or uncataloged
    newproperty(:ensure, :required_features => :ensurable) do
      desc "Whether a database should be cataloged or uncataloged at a node."

      newvalue(:uncatalog, :event => :db2_uncatalog) do
        provider.uncatalog
      end

      newvalue(:catalog, :event => :db2_catalog, :invalidate_refreshes => true) do
        provider.catalog
      end

      aliasvalue(:absent, :uncatalog)
      aliasvalue(:present, :catalog)
    end

    newparam(:name, :namevar => true) do
      desc "The unique name for the DB2 connectivity."
    end

    newparam(:db_name) do
      desc "The database name"
    end

    newproperty(:db2_type) do
      desc "The type of DB2 database"

      defaultto :DB2UNIX

      newvalues(:DB2ODBC, :db2odbc, :DB2UNIX, :db2unix)
    end

    newproperty(:db2_host) do
      desc "The host name of the DB2 database server."

      validate do |value|
        value.split('.').each do |hostpart|
          unless hostpart =~ /^([\d\w]+|[\d\w][\d\w\-]+[\d\w])$/
            raise Puppet::Error, "Invalid host name"
          end
        end
        if (value =~ /\n/ || value =~ /\r/)
          raise Puppet::Error, "Hostname cannot include newline"
        end
      end
    end

    newproperty(:db2_port) do
      desc "The port on which the DB2 database server is listening for client
        connections."

      defaultto 60030

      newvalues(/^\d+$/)

      munge do |value|
        Integer(value)
      end
    end

    newproperty(:db2_node) do
      desc "The DB2 node name used for cataloging and uncataloging"
    end

    newparam(:db2_target_db) do
      desc "The target database name"
    end

    newproperty(:db2_user_name) do
      desc "The user name for the DB2 database"
    end

    newproperty(:db2_user_pwd) do
      desc "The user password for the DB2 database"
    end

    newparam(:db2_instance_user) do
      desc "The database instance user"
    end

    newparam(:db2_sqllib_dir) do
      desc "Specify the directory where DB2 sqllib is installed"

      validate do |value|
        unless Puppet::Util.absolute_path?(value)
          fail Puppet::Error, "DB2 sqllib path must be fully qualified, not '#{value}'"
        end
      end
    end

    parameter :ps_home_dir
  end
end
