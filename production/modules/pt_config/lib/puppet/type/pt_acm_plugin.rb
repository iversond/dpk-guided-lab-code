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
  Type.newtype(:pt_acm_plugin) do
    include EasyType
    include Puppet::Util::Execution
    include ::PtCompUtils::Validations

    @doc = "Invoke an Automated Config Manager (ACM) Plugin to configure a
      PeopleSoft component from command line:"

    validate do
      validate_domain_params(self[:os_user], self[:ps_home_dir])

      # make sure db_settings is specified
      if self[:db_settings].nil?
        fail("db_settings should be specified to run an ACM Plugin")
      end

      # make sure atleast one plugin is specified
      plugin_list = self[:plugin_list]
      if plugin_list.nil? || plugin_list.empty?
        fail("Atleast one plugin needs to be specified " +
             "#{self[:plugin_list].inspect}")
      end

      # make sure atleast one property is specified for each plugin
      plugin_list = [plugin_list] unless plugin_list.is_a? Array
      plugin_list.each do |plugin|
        Puppet.debug("Got a plugin")
        if plugin.split('=', 2)[1].nil?
          raise ArgumentError, "Key/value pairs must be separated by an ="
        end
        plugin_name = plugin.split('=', 2)[0].strip
        Puppet.debug("The plugin Name is : #{plugin_name}")
        plugin_props = plugin.split('=', 2)[1].strip

        if plugin_props.nil? || plugin_props.empty?
          fail("Atleast one property needs to be specified " +
              "for plugin #{plugin_name}")
        end
        plugin_props = [plugin_props] unless plugin_props.is_a? Array
        plugin_props.each do |prop|
          if prop.split('=', 2)[1].nil?
            raise ArgumentError, "Properties name/value pairs must be " +
                                 "separated by an ="
          else
            prop.split(', ').each do |prop_item|
              if ['pwd', 'pass'].any? {|var| prop_item.split('=')[0].include? var}
                Puppet.debug("Got the property: #{prop_item.gsub(prop_item.split('=')[1], '*****')}")
              else
                Puppet.debug("Got the property: #{prop_item}")
              end
            end
          end
        end
      end
    end

    newparam(:name, :namevar => true) do
    end

    newparam(:run_control_id) do
      desc "The run control ID to use for this run."
    end

    newparam(:program_id) do
      desc "Specify the Application Engine program to run."
      defaultto :PTEM_CONFIG
#      newvalues (:PTEM_CONFIG) 
    end

    newparam(:process_instance) do
      desc "Required for restart, enter the process instance for the program
        run. The default is 0, which means  Application Engine uses the next
        available process instance."

      defaultto 0

      munge do |value|
        Integer(value)
      end
    end

    newparam(:plugin_list, :array_matching => :all) do
      desc "List of Plugins to run. The plugins are passed in as an
        Array of key value pairs. The key corresponds to the name
        of the Plugin and the value in turns contains an array of
        name value pairs of the plugin properties."

    end

    newproperty(:returns, :array_matching => :all,
                :event => :executed_acm_plugin) do |property|
      include Puppet::Util::Execution
      munge do |value|
        value.to_s
      end

      def event_name
        :executed_acm_plugin
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

      # Actually execute the ACM Plugin
      def sync
        event = :executed_acm_plugin

        @output, @status = provider.run_acm_plugin()

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
          self.fail("ACM Plugin execution returned #{@status} instead of " +
                    "one of [#{self.should.join(",")}]")
        end

        event
      end
    end

    newparam(:persist_property_file, :boolean => true, :parent => Puppet::Parameter::Boolean) do
      desc "Flag that specified whether to persist the plugin properties file."

      defaultto false
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
