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
  newfunction(:strip_keyval_array, :type => :rvalue, :doc => <<-EOS
    This function strips whitespace between each key = value array element of
    the passed array. The return value is an array with compacted key=value
    elements.

    *Examples:*

      strip_keyval_array([ "a = 1", "b = 2", "c = 3" ]

    Would result in: ["a=1","b=2","c=3"]
    EOS
  ) do |arguments|
    # Validate the number of arguments.
    if arguments.size != 1
      raise(Puppet::ParseError, "strip_keyval_array(): Takes exactly one " +
        "argument, but #{arguments.size} given.")
    end
    # Validate the first argument.
    array = arguments[0]
    if not array.is_a?(Array)
      raise(TypeError, "strip_keyval_array(): The first argument must be a " +
        "array, but a #{array.class} was given.")
    end
    ret=[]
    # strip whitespace
    array.each do |element|
      key = element.split('=')[0].strip
      if element.split('=')[1].nil? == false
        val = element.split('=', 2)[1].strip
      else
        val = ''
      end

      new_element = key + '=' + val
      ret.push(new_element)
    end
    return ret
  end
end
