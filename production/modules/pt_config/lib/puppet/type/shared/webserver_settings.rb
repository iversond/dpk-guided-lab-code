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

newparam(:webserver_settings, :array_matching => :all) do
  include EasyType

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

  validate do |values|
    values = [values] unless values.is_a? Array
    Puppet.debug("Webserver properties are processed")
    values.each do |item|
      item_val = item.split('=')[1]
      key = item.split('=')[0].strip
      if item_val.nil?
        raise ArgumentError, "Key/value pairs must be separated by an ="
      elsif ['pwd', 'pass'].any? {|var| key.downcase.include? var}
        Puppet.debug("Got item: #{item.gsub(item.split('=')[1], '****')}")
      else
        Puppet.debug("Got item: #{item}")
      end
      # validate the webserver type
      if key == 'webserver_type'
        item_val = item_val.strip
        if (item_val != 'weblogic') and
           (item_val != 'websphere') and
           (item_val != 'ohs')
          fail("WebServer type should be either 'weblogic' or 'websphere' or 'ohs' " +
               " got: [#{item_val}]")
        end
        if item_val == 'websphere'
          fail("WebSphere is not supported as the WebServer in this release")
        end
      end
    end
  end

  munge do |values|
    webserver_hash = {}

    values = [values] unless values.is_a? Array
    values.each do |value|
      webserver_hash[value.split('=')[0].strip.to_sym] =
          value.split('=')[1].strip
    end
    if provider.respond_to?(:webserver_hash=)
      provider.webserver_hash=(webserver_hash)
    end
    return webserver_hash
  end
end
