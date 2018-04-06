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

module Puppet
  Type.newtype(:pt_psae) do
    include EasyType
    include Puppet::Util::Execution
    include ::PtCompUtils::Validations

    @doc = "Invoke an PeopleSoft Application Engine program through the
      command line to:

    * Restart
      When a program abends, a system administrator might restart the program
      using the command line. If needed, you can locate all of the specific
      program and process information from Process Monitor in the Process
      Request Detail dialog box. Normally, users or system administrators
      perform a restart from the Process Monitor.

    * Develop or test
      Many developers include the command line in a batch file to launch a
      program they are developing or testing. This way, they can quickly
      execute the batch file as needed. This method also enables separation
      of development of the application program from its associated pages.

    * Debug
      To debug a program running on the server, you can sign into the server
      (using telnet, for example) and invoke the program from the command
      line."

    validate do
      validate_domain_params(self[:os_user], self[:ps_home_dir])

      # make sure db_settings is specified
      if self[:db_settings].nil?
        fail("db_settings should be specified to run an AE")
      end
    end

    newparam(:run_control_id, :namevar => true) do
      desc "The run control ID to use for this run of the program."
    end

    newparam(:program_id) do
      desc "Specify the Application Engine program to run."
    end

    newparam(:process_instance) do
      desc "Required for restart, enter the process instance for the program
        run. The default is 0, which means Application Engine uses the next
        available process instance."

      defaultto 0

      munge do |value|
        Integer(value)
      end
    end

    newparam(:restart_enable) do
      desc "This parameter controls restart disabling. Enter yes to disable
        restart or enter no to enable restart."

      defaultto :no

      newvalues(:yes, :no)
    end

    newproperty(:returns, :array_matching => :all,
                :event => :executed_ae) do |property|
      include Puppet::Util::Execution
      munge do |value|
        value.to_s
      end

      def event_name
        :executed_ae
      end

      defaultto "0"

      attr_reader :output
      desc "The expected exit code(s). An error will be returned if the
        executed command has some other exit code. Defaults to 0. Can be
        specified as an array of acceptible exit codes or a single value."

      # Make output a bit prettier
      def change_to_s(currentvalue, newvalue)
        "executed successfully"
      end

      # Actually execute the AE.
      def sync
        event = :executed_ae

       @output, @status = provider.run_ae()

        if log = @resource[:logoutput]
          case log
          when :true
            log = @resource[:loglevel]
          when :on_failure
            unless self.should.include?(@status.to_s)
              log = @resource[:loglevel]
            else
              log = :false
            end
          end
          unless log == :false
            @output.split(/\n/).each { |line|
              self.send(log, line)
            }
          end
        end

        unless self.should.include?(@status.to_s)
          self.fail("Application Engine execution returned #{@status} " +
                    "instead of one of [#{self.should.join(",")}]")
        end

        event
      end
    end

    parameter :os_user
    parameter :logoutput
    parameter :ps_home_dir
    parameter :db_settings

    def output
      if self.property(:returns).nil?
        return nil
      else
        return self.property(:retuns).output
      end
    end
  end
end
