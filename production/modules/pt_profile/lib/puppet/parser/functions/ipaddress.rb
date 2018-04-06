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

module Puppet::Parser::Functions
  newfunction(:ipaddress, :type => :rvalue, :doc => <<-EOS
    This function takes in a host name and generates a ipaddress.
    EOS
  ) do |arguments|
    # Validate the number of arguments.
    if arguments.size != 1
      raise(Puppet::ParseError, "ipaddress(): Takes exactly one " +
        "argument, but #{arguments.size} given.")
    end
    # Validate the first argument.
    input_str = arguments[0]
    if not input_str.is_a?(String)
      raise(TypeError, "ipaddress(): The first argument must be a " +
        "string, but a #{input_str.class} was given.")
    end

    begin
    return Resolv.getaddress(input_str)
    rescue Exception => e
      begin
      raise(Puppet::ParseError, "Unable to get the ipaddress " +
            "for hostname #{input_str}, Error: #{e.message}")
      end
    end
  end
end
