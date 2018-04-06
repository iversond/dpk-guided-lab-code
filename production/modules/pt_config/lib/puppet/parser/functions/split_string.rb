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
  newfunction(:split_string, :type => :rvalue, :doc => <<-EOS
    This function strips a string based on a delimiter and returns an array of
    two strings.

    *Examples:*

      strip_string("hard.nproc", '.')

    Would result in: [ "hard", "nproc" ]
    EOS
  ) do |arguments|
    # Validate the number of arguments.
    if arguments.size != 2
      raise(Puppet::ParseError, "strip_string(): Takes exactly two " +
        "argument, but #{arguments.size} given.")
    end
    # Validate the first argument.
    input_str = arguments[0]
    if not input_str.is_a?(String)
      raise(TypeError, "strip_string(): The first argument must be a " +
        "string, but a #{input_str.class} was given.")
    end
    # Validate the second argument.
    split_char = arguments[1]
    if not split_char.is_a?(String)
      raise(TypeError, "strip_string(): The second argument must be a " +
        "single character, but a #{split_char} was given.")
    end
    if split_char.size != 1
      raise(TypeError, "strip_string(): The second argument must be a " +
        "single character, but a #{split_char} was given.")
    end
    return input_str.split(split_char)
  end
end
