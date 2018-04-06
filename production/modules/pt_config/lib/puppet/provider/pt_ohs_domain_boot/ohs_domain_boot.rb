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

require 'puppet/provider/ohs_utils'
require 'pt_comp_utils/validations'
require 'pt_comp_utils/webserver'

Puppet::Type.type(:pt_ohs_domain_boot).provide :ohs_domain_boot do
  include ::PtCompUtils::Validations
  include ::PtCompUtils::WebServer

  desc "The OHS domain boot provider."

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  mk_resource_methods

  def self.instance
    []
  end

  @webserver_hash = {}

  def webserver_hash=(webserver_hash)
    Puppet.debug("Caching Webserver settings")
    @webserver_hash = webserver_hash
  end

  # How to restart the domain
  def restart
    Puppet.debug("Action restart called")
    self.stop_domain
    self.start_domain
  end

  def status
    Puppet.debug("Action status called")
    domain_name = resource[:domain_name]

    if Facter.value(:osfamily) == 'windows'
      os_user = ''
    else
      os_user = resource[:os_user]
    end
    node_manager_port = resource[:node_manager_port]

    begin
      # check the status of the domain first
      return OHSUtils.check_domain_status(os_user, domain_name,
                                 node_manager_port, @webserver_hash)
    rescue Puppet::ExecutionFailure => e
      raise Puppet::ExecutionFailure, "Unable to start domain #{domain_name}: #{e.message}"
    end
  end

  def stop_domain
    Puppet.debug("Action stop called")
    domain_name = resource[:domain_name]

    Puppet.debug("Stopping domain: #{domain_name}")

    if Facter.value(:osfamily) == 'windows'
      os_user = ''
    else
      os_user = resource[:os_user]
    end
    domain_home_dir = resource[:domain_home_dir]

    OHSUtils.stop_domain(os_user, domain_name, domain_home_dir, @webserver_hash)
  end

  def start_domain
    Puppet.debug("Action start called")
    domain_name = resource[:domain_name]

    Puppet.debug("Starting domain: #{domain_name}")

    if Facter.value(:osfamily) == 'windows'
      os_user = ''
    else
      os_user = resource[:os_user]
    end
    domain_home_dir = resource[:domain_home_dir]
    node_manager_port = resource[:node_manager_port]

    OHSUtils.start_domain(os_user, domain_name, domain_home_dir, node_manager_port, @webserver_hash)
  end
end
