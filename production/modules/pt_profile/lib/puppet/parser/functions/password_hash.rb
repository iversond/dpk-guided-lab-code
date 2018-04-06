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
  newfunction(:password_hash, :type => :rvalue, :doc => <<-EOS
    This function takes in a string and generates a hash. This has
    is will be used as the password value.
    EOS
  ) do |arguments|
    # Validate the number of arguments.
    if arguments.size != 1
      raise(Puppet::ParseError, "password_hash(): Takes exactly one " +
        "argument, but #{arguments.size} given.")
    end
    # Validate the first argument.
    input_str = arguments[0]
    if not input_str.is_a?(String)
      raise(TypeError, "password_hash(): The first argument must be a " +
        "string, but a #{input_str.class} was given.")
    end
    return input_str.crypt('$6$' + rand(36 ** 8).to_s(36))
  end
end
