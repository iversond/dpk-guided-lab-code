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

newparam(:db_settings, :array_matching => :all) do
  include EasyType

  desc "Specify the database connectivity information.
    The connectivity information is specified as an array of parameter = value
    pairs. The array should include the following parameters:

    db_name:        The name of the database to connect to

    db_type:        Indicates the database type. Valid values are ORACLE,
                    MSSQL, DB2ODBC, and DB2UNIX

    db_opr_id:      The user ID to use to connect to the database

    db_opr_pwd:     The user password that is associated with the user ID

    db_connect_id:  The connect ID of the database

    db_connect_pwd: The password that is associated with the connect ID"

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
      fail("#{k} needs to be specified in the db_connectivity parameter")
    end
    temp_hash = {}
    values.each do |item|
      temp_hash[item.split('=')[0].strip.to_sym]=item.split('=')[1].strip
    end
    values_hash.update(temp_hash)

    # validate to make sure all the required parameters are specified in
    # the array
    key_db_name        = :db_name
    key_db_type        = :db_type
    key_db_opr_id      = :db_opr_id
    key_db_opr_pwd     = :db_opr_pwd
    key_db_connect_id  = :db_connect_id
    key_db_connect_pwd = :db_connect_pwd

    values_hash[key_db_name]
    db_type = values_hash[key_db_type]
    values_hash[key_db_opr_id]
    values_hash[key_db_opr_pwd]
    values_hash[key_db_connect_id]
    values_hash[key_db_connect_pwd]

    # validate the database type
    supported_db_list = [ 'ORACLE', 'MSSQL', 'DB2ODBC', 'DB2UNIX' ]
    if ! supported_db_list.include?(db_type.upcase)
      fail("Specified db type '#{db_type}' is not one of supported " + \
           "supported databases #{supported_db_list.inspect}")
    end
  end

  munge do |values|
    db_hash = {}

    values = [values] unless values.is_a? Array
    values.each do |value|
      db_hash[value.split('=')[0].strip.to_sym]=value.split('=')[1].strip
    end
    if provider.respond_to?(:db_hash=)
      provider.db_hash=(db_hash)
    end
    return db_hash
  end
end
