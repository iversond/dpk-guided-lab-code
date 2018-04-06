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

require 'tempfile'
require 'puppet/provider/webappdomain'

Puppet::Type.type(:pt_opa_domain).provide :opa_domain,
                  :parent => Puppet::Provider::WebAppDomain do

  if Facter.value(:osfamily) != 'windows'
    commands :domain_cmd =>  'su'
  end

  mk_resource_methods

  private

  def configure_domain
    # update the OPA application properties file
    application_prop_file = File.join(resource[:webapp_dir], 'webserv',
                                      resource[:domain_name], 'applications',
                                      'opa', 'WEB-INF', 'classes', 'config',
                                      'application.properties')
    Puppet.debug("Updating application prop file #{application_prop_file}")
    file_content_orig = File.read(application_prop_file)
    file_content_mod = file_content_orig.gsub(/response.outcomes.only.*/,
                                     'response.outcomes.only      =true')
    File.open(application_prop_file, "w") { |file| file << file_content_mod }

    super()
  end

  def get_response_file
    response_file_path = super()

    # add OPA relarted properties to the response file
    open(response_file_path,  'a') do |response_file|
      response_file.puts('WAR_FILE=' + resource[:opa_war_file])

      ps_app_home = resource[:ps_app_home_dir]
      opa_dir = File.join(ps_app_home, 'setup', 'archives', 'opa')
      response_file.puts('RULES_FILE=' +  opa_dir)
    end
    return response_file_path
  end
end
