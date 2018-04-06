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
  Type.newtype(:pt_compile_cobol) do
    include EasyType

    @doc = "This type compiles COBOL sources in PS_HOME & PS_APP_HOME, PS_CUST_HOME if present"

    validate do
      # make sure PS Home is specified
      if self[:ps_home_dir].nil?
        fail("ps_home_dir should be specified for compiling cobol sources")
      end
      # make sure the COBOL home is specified
      if self[:cobol_home_dir].nil?
        fail("cobol_home_dir should be specified for compiling cobol sources")
      end
      if Facter.value(:osfamily) != 'Windows'
        # check to see if ps_home_owner is specified
        if self[:ps_home_owner].nil?
          fail("ps_home_owner should be specified for compiling PS_HOME " +
               " cobol sources")
        end
        if self[:ps_app_home_dir].nil? == false
          if self[:ps_app_home_owner].nil?
            fail("ps_app_home_owner should be specified for compiling PS_APP_HOME " +
                 " cobol sources")
          end
        end
        if self[:ps_cust_home_dir].nil? == false
          if self[:ps_cust_home_owner].nil?
            fail("ps_cust_home_owner should be specified for compiling PS_CUST_HOME " +
                 " cobol sources")
          end
        end
      end
    end

    newparam(:name, :namevar => true) do
      desc "The place holder for uniqueness."
    end

    newproperty(:action) do
      desc "The action to perform"

      defaultto :compile

      newvalues(:compile)

      newvalue(:compile, :event => :compile_cobol, :invalidate_refreshes => true) do
        provider.compile_cobol
      end
    end

    newparam(:cobol_home_dir) do

      desc "Specify the directory where COBOL is installed"

      validate do |value|
        unless Puppet::Util.absolute_path?(value)
          fail Puppet::Error, "COBOL path must be fully qualified, not '#{value}'"
        end
      end
    end

    newparam(:ps_home_owner) do
      desc "* Unix Only * The user who installed PS_HOME"

      validate do |value|
        if Facter.value(:osfamily) == 'Windows'
          fail("Unable to execute commands as other users on Windows")
        elsif !Puppet.features.root? && Etc.getpwuid(Process.uid).name != value
          fail("Only root can execute commands as other users")
        end
        puts self.resource[:ps_home_owner]
      end
    end

    newparam(:ps_app_home_owner) do
      desc "* Unix Only * The user who installed PS_APP_HOME"

      validate do |value|
        if Facter.value(:osfamily) == 'Windows'
          fail("Unable to execute commands as other users on Windows")
        elsif !Puppet.features.root? && Etc.getpwuid(Process.uid).name != value
          fail("Only root can execute commands as other users")
        end
        puts self.resource[:ps_app_home_owner]
      end
    end

    newparam(:ps_cust_home_owner) do
      desc "* Unix Only * The user who owns PS_CUST_HOME"

      validate do |value|
        if Facter.value(:osfamily) == 'Windows'
          fail("Unable to execute commands as other users on Windows")
        elsif !Puppet.features.root? && Etc.getpwuid(Process.uid).name != value
          fail("Only root can execute commands as other users")
        end
        puts self.resource[:ps_cust_home_owner]
      end
    end
    parameter :ps_home_dir
    parameter :ps_app_home_dir
    parameter :ps_cust_home_dir
  end
end
