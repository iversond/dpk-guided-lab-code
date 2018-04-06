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
  newfunction(:compare_arrays, :type => :rvalue,
              :doc => <<-'ENDHEREDOC') do |args|
    This function takes in two arrays, and makes sure they have the same set of
      values. The values need not be in the same order in both the arrays. Returns
      true if they are the same else returns false.

    ENDHEREDOC

    if args.length < 2
      raise Puppet::ParseError, ("compare_arrays(): wrong number " + \
                                 "of args (#{args.length}; must be 2)")
    end

    array_one = args[0]
    unless array_one.is_a?(Array)
      raise(Puppet::ParseError, "compare_arrays(): first arg " + \
                                "must be an Array, got #{array_one.class}")
    end

    array_two = args[1]
    unless array_two.is_a?(Array)
      raise(Puppet::ParseError, "compare_arrays(): second arg " + \
                                "must be an Array, got #{array_two.class}")
    end

    # make sure the array lengths are the same first
    array_one_length = array_one.length
    array_two_length = array_two.length

    Puppet.debug("Array one length: #{array_one_length}")
    Puppet.debug("Array two length: #{array_two_length}")
    match = true
    if array_one_length != array_two_length
       match = false
    end
    for index in 0..array_one_length - 1
       component = array_one[index]
       Puppet.debug("Match component: #{component}")

       # check if this component exists in the second array
       if array_two.include?(component) == false
          match = false
          break
       end
    end
    Puppet.debug("Compare arrays: #{match}")
    return match
  end
end
