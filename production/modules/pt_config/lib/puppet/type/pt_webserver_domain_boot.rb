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
require 'pt_comp_utils/validations'
require 'pt_comp_utils/webserver'

module Puppet

  Type.newtype(:pt_webserver_domain_boot) do
    include EasyType
    include ::PtCompUtils::Validations
    include ::PtCompUtils::WebServer

    @doc = "Manage PeopleSoft PIA domain boot.

      **Refresh:** `boot` resources can respond to refresh events (via
      `notify`, `subscribe`, or the `~>` arrow). If a `boot` receives an
      event from another resource, Puppet will restart the domain it manages."

    feature :refreshable, "The provider can restart the domain.",
      :methods => [:restart]

    validate do
      validate_domain_params(self[:os_user], self[:ps_cfg_home_dir])

      ensure_value = self[:ensure].to_s
      if ensure_value == 'running'
        ensure_value = 'present'
      end
      validate_webserver_settings(ensure_value, self[:webserver_settings])
    end

    property :ensure
    parameter :domain_name
    parameter :os_user
    parameter :ps_cfg_home_dir
    parameter :webserver_settings

    # Basically just a synonym for restarting.  Used to respond
    # to events.
    def refresh
      # Only restart if we're actually running
      if (@parameters[:ensure] || newattr(:ensure)).retrieve == :running
        provider.restart
      else
        debug "Skipping restart; domain is not running"
      end
    end
  end
end
