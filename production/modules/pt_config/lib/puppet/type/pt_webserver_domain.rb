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
require 'pt_comp_utils/webserver'
require 'puppet/parameter/boolean'

module Puppet
  Type.newtype(:pt_webserver_domain) do
    include EasyType
    include ::PtCompUtils::Validations
    include ::PtCompUtils::WebServer

    @doc = "Manages the state of PeopleTools Web Server domain."

    validate do
      validate_domain_params(self[:os_user], self[:ps_home_dir])
      ensure_value = self[:ensure].to_s

      validate_webserver_settings_array(ensure_value, self[:webserver_settings])

      # make sure atleast one site is specified
      site_list = self[:site_list]
      if site_list.nil? || site_list.empty?
        fail("Atleast one site needs to be specified #{self[:site_list].inspect}")
      end

      # make sure the  ps_cfg_home_dir is given
      if self[:ps_cfg_home_dir].nil?
        raise ArgumentError, "PS_CFG_HOME home directory needs to be " +
                             "specified to manage a WebServer domain"
      end
    end

    ensurable

    newparam(:gateway_user) do
      desc "The Integration Gateway user name."

      defaultto 'administrator'
    end

    newparam(:gateway_user_pwd) do
      desc "The Integration Gateway user password."

      validate do |value|
        if value.match(/^(?=.*[\w]).{8,}$/).nil?
          fail("Integration Gateway user password must be at least 8 " +
               "alphanumeric characters.")
        end
      end
    end

    newproperty(:auth_token_domain) do
      desc "The name of the Authentication Token Domain."
    end

    newproperty(:config_settings, :array_matching => :all) do
      desc "Specifies the list of configuration settings to be applied
           to the Web Server domain."

      validate do |values|
        # make sure atleast one setting is specified for each context
        values = [values] unless values.is_a? Array
        Puppet.debug("Config properties: #{values.inspect}")
        values.each do |context|
          Puppet.debug("Got context: #{context.inspect}")
          if context.split('=', 2)[1].nil?
            raise ArgumentError, "Key/value pairs must be separated by an ="
          end
          context_name = context.split('=', 2)[0].strip
          Puppet.debug("Got context Name: #{context_name}")
          context_settings = context.split('=', 2)[1].strip
          if context_settings.nil? || context_settings.empty?
            fail("Atleast one setting needs to be specified " +
                 "for context #{context_name}")
          end
          context_settings = [context_settings] unless context_settings.is_a? Array
          context_settings.each do |setting|
            Puppet.debug("Got setting: #{setting}")
            if setting.split('=', 2)[1].nil?
              raise ArgumentError, "Settings name/value pairs must be " +
                                   "separated by an ="
            end
          end
        end
      end
    end


    newproperty(:webserver_settings, :array_matching => :all) do
      desc "The WebServer Properties. These properties are used to
           manage the domain/profile of the WebServer.

           webserver_type:           The type of the WebServer used for
                                     PeopleSoft Application.
                                     Valid values: weblogic, websphere, ohs

           webserver_home:           location of the WebServer installation

           webserver_admin_user:     admin user of the WebServer installation
                                     Applicable to Weblogic and ohs only.

           webserver_admin_user_pwd: password for the admin user
                                     Applicable to Weblogic and ohs only

           webserver_admin_port:     Admin port of the WebServer
           webserver_http_port:      HTTP Listen port of the Webserver
           webserver_https_port:     HTTPS Listen port of the Webserver"

      validate do |value|
        raise ArgumentError, "Key/value pairs must be separated by an =" unless value.include?("=")
      end

      munge do |values|
        values = [values] unless values.is_a? Array
        values.each do |value|
          if provider.respond_to?(:webserver_hash_add)
            provider.webserver_hash_add(value.split('=')[0].strip, value.split('=')[1].strip)
          end
        end
        return values
      end
    end

    newproperty(:site_list, :array_matching => :all) do
      desc "Specifies the list of sites configured in this
           PeopleSoft eb Server domain."

      validate do |values|
        # make sure atleast one site is specified
        values = [values] unless values.is_a? Array
        values.each do |site|
          Puppet.debug("Got a site")
          if site.split('=', 2)[1].nil?
            raise ArgumentError, "Key/value pairs must be separated by an ="
          end
          site_name = site.split('=', 2)[0].strip
          Puppet.debug("Got site name: #{site_name}")

          site_settings = site.split('=', 2)[1].strip
          if site_settings.nil? || site_settings.empty?
            fail("Atleast one setting needs to be specified " +
                 "for the site #{site_name}")
          end
          site_settings = site_settings.split(", ")
          Puppet.debug("Site attributes are as follows")

          # convert the array into hash for easy validations
          site_settings_hash = Hash.new do |h,k|
            fail("#{k} needs to be specified has a site parameter")
          end
          temp_hash = {}
          site_settings.each do |site_setting|
            site_setting_key = site_setting.split('=', 2)[0].strip
            site_setting_key.delete!("\n[]\"")

            site_setting_val = site_setting.split('=', 2)[1].strip
            site_setting_val.delete!("[]\"")
            if ['pwd', 'pass', 'webprofile_settings'].any? {|var| site_setting_key.downcase.include? var}
              Puppet.debug("Site settings parameter #{site_setting_key}:****")
            else
              Puppet.debug("Site settings parameter #{site_setting_key}:#{site_setting_val}")
            end
            temp_hash[site_setting_key.to_sym]=site_setting_val
          end
          site_settings_hash.update(temp_hash)

          # validate to make sure all the required parameters are specified in
          # the site settings
          key_appserver_connections = :appserver_connections
          key_report_repository_dir = :report_repository_dir
          key_webprofile_settings   = :webprofile_settings

          site_settings_hash[key_appserver_connections]
          webprofile_settings = site_settings_hash[key_webprofile_settings]

          # make sure Web Profile settings are given
          if webprofile_settings.nil? || webprofile_settings.empty?
            raise ArgumentError, "webprofile_settings needs to be specified " +
                                 "for a PIA domain site"
          end
          webprofile_settings = webprofile_settings.split(",")
          Puppet.debug("Webprofile profile settings are captured")

          # convert the array into hash for easy validations
          webprofile_settings_hash = Hash.new do |h,k|
            fail("#{k} needs to be specified in the web_profile parameter")
          end
          temp_hash = {}
          webprofile_settings.each do |webprofile_setting|
            webprofile_setting_key = webprofile_setting.split('=', 2)[0].strip
            webprofile_setting_key.delete!("\n[]\"")
            webprofile_setting_val = webprofile_setting.split('=', 2)[1].strip
            webprofile_setting_val.delete!("\n[]\"")
            if ['pwd', 'pass'].any? {|var| webprofile_setting_key.downcase.include? var}
              Puppet.debug("Webserver settings: #{webprofile_setting_key}:****")
            else
              Puppet.debug("Webserver settings key: #{webprofile_setting_key}, value: #{webprofile_setting_val}")
            end
            temp_hash[webprofile_setting_key.to_sym]=webprofile_setting_val
          end
          webprofile_settings_hash.update(temp_hash)

          # validate to make sure all the required web profile parameters are
          # specified
          key_profile_name = :profile_name
          key_profile_user = :profile_user
          key_profile_pwd  = :profile_user_pwd

          profile_name = webprofile_settings_hash[key_profile_name]
          # validate to make sure profile value is one of the predefined ones
          valid_profile_names = [ "DEV", "KIOSK", "PROD", "TEST" ]
          if ! valid_profile_names.include?(profile_name)
            fail("Specified profile name '#{profile_name}' is not one of " +
                 "valid profile names '#{valid_profile_names.inspect}")
          end
          webprofile_settings_hash[key_profile_user]
          profile_user_pwd = webprofile_settings_hash[key_profile_pwd]
          if profile_user_pwd.match(/^(?=.*[\w]).{8,}$/).nil?
            fail("Web profile user password must be at least 8 alphanumeric characters.")
          end

          report_repository_dir = site_settings_hash[key_report_repository_dir]
          unless Puppet::Util.absolute_path?(report_repository_dir)
            fail("Report Repository Root must be fully qualified, not '#{report_repository_dir}'")
          end
        end
      end

      munge do |values|
        site_hash = {}

        values = [values] unless values.is_a? Array
        values.each do |value|
          site_name     = value.split('=', 2)[0].strip
          site_settings = value.split('=', 2)[1].strip

          site_settings = site_settings.split(", ")
          Puppet.debug("Got site attributes for the web profile")

          site_settings_hash = {}
          site_settings.each do |site_setting|
            site_setting_key = site_setting.split('=', 2)[0].strip
            site_setting_key.delete!("\n[]\"")
            site_setting_val = site_setting.split('=', 2)[1].strip
            site_setting_val.delete!("[]\"")

            if site_setting_key.to_sym == :webprofile_settings
              site_webprofile_hash = {}
              site_webprofile_settings = site_setting_val.split(",")
              Puppet.debug("Got site webprofile attributes for the site")

              site_webprofile_settings.each do |site_webprofile_setting|
                site_webprofile_setting_key = site_webprofile_setting.split('=', 2)[0].strip
                site_webprofile_setting_key.delete!("\n[]\"")
                site_webprofile_setting_val = site_webprofile_setting.split('=', 2)[1].strip
                site_webprofile_setting_val.delete!("\n[]\"")
                if ['pwd', 'pass'].any? {|var| site_webprofile_setting_key.downcase.include? var}
                  Puppet.debug("Webprofile settings key: #{site_webprofile_setting_key}:****")
                else
                  Puppet.debug("Webprofile settings key: #{site_webprofile_setting_key}, value: #{site_webprofile_setting_val}")
                end
                site_webprofile_hash[site_webprofile_setting_key.to_sym] = site_webprofile_setting_val
              end
              site_settings_hash[site_setting_key.to_sym] = site_webprofile_hash
            else
              site_settings_hash[site_setting_key.to_sym] = site_setting_val
            end
          end
          site_hash[site_name] = site_settings_hash
        end
        if provider.respond_to?(:site_hash_add)
          provider.site_hash_add(site_hash)
        end
        return site_hash
      end
    end

    newproperty(:patch_list, :array_matching => :all) do
      desc "Specify  a list of patches pertitent to the component"

      validate do |values|
        values = [values] unless values.is_a? Array
        values.each do |item|
          Puppet.debug("Got patch file : #{item}")

          # check to make sure the patch file is specified as an absolute path
          unless Puppet::Util.absolute_path?(item)
            fail Puppet::Error, "The patch file must be fully qualified, not '#{item}'"
          end
          if File.file?(item) == false
            fail Puppet::Error, "The patch file '#{item}' does not exists"
          end
        end
      end
    end

    parameter :domain_name
    parameter :os_user
    parameter :ps_home_dir
    parameter :ps_cfg_home_dir
    parameter :domain_start
    parameter :recreate
  end
end
