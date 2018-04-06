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

module Puppet
  Type.newtype(:pt_tns_entry) do

    @doc = "Adds or deletes TNS entry for Oracle database."

    validate do
      # make sure DB name is specified
      if self[:db_name].nil?
        fail("db_name should be specified for managing a TNS entry")
      end
      # make sure the TNS names file is specified
      if self[:tns_file_name].nil?
        fail("tns_file_name should be specified for managing a TNS entry")
      end
      if self[:db_service_name].nil?
        fail("db_service_name should be specified for managing a TNS entry")
      end
    end

    ensurable

    newparam(:name, :namevar => true) do
      desc "The unique name for the tns entry."
    end

    newparam(:db_name) do
      desc "The unique name (SID) that uniquely identifies the database
        instance."
    end

    newproperty(:db_host) do
      desc "The host name of the Oracle database server."

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

    newproperty(:db_port) do
      desc "The port on which the Oracle database is listening for client
        connections."

      defaultto 1521

      newvalues(/^\d+$/)

      munge do |value|
        Integer(value)
      end
    end

    newproperty(:db_protocol) do
      desc "The protocol being used to communicate between client and
        Oracle database server.  protocol can be one of the following:
              - TCP
              - SDP (used on Exalogic)"

      defaultto :TCP

      if Facter.value(:exalogic)  == false
        newvalues(:TCP)
      else
        newvalues(:TCP, :SDP)
      end

    end

    newproperty(:db_service_name) do
      desc "The database instance name that is registered with the database
        listener."
    end

    newparam(:db_is_rac, :boolean => false, :parent => Puppet::Parameter::Boolean) do

      desc "flag that denotes whether the database connected it RaC or not"

      defaultto false
    end

    newparam(:tns_file_name) do
      desc "The TNS admin file."

      validate do |value|
        unless Puppet::Util.absolute_path?(value)
          fail Puppet::Error, "TNS file name must be fully qualified, "
                              "not '#{value}'"
        end
      end
    end
  end
end
