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
  newfunction(:hash_of_hash_to_array_of_array, :type => :rvalue, :arity => -2,
              :doc => <<-'ENDHEREDOC') do |args|
    Converts an hash of keys => values into an array of 'key = value' elements.
      The value of each hash element is in turn an hash and this hash is  also
      converted to a array. The function takes in an optional array that specifies
      the order in which the array should be constructed from the hash.

      For example:

        $my_hash = {
          one => { a=> b },
          two => { x=> y },
        }
        $my_array = hash_of_hash_to_array_of_array($my_hash)
        # The resulting array is equivalent to:
        #   $my_array = [ 'one = [ a = b]', 'two = [x = y]' ]

    ENDHEREDOC

    if args.length < 1
      raise Puppet::ParseError, ("hash_of_hash_to_array_of_array(): wrong number " + \
                                 "of args (#{args.length}; must be 1)")
    end

    my_hash = args[0]
    unless my_hash.is_a?(Hash)
      raise(Puppet::ParseError, "hash_of_hash_to_array_of_array(): first arg " + \
                                "must be an Hash, got #{my_hash.class}")
    end

    sort_array = args[1]
    if sort_array.nil?
      sort_array = my_hash.keys
      Puppet.debug("Sorting Array not specified, using Hash keys: #{sort_array.inspect}")
    else
      unless sort_array.is_a?(Array)
        raise(Puppet::ParseError, "hash_of_hash_to_array_of_array(): second arg " + \
                                  "must be an Array, got #{sort_array.class}")
      end
    end
    my_array_outer = []
    num_elements = sort_array.size
    Puppet.debug("Sort Array size: #{num_elements}")

    for index in 0..(num_elements - 1)
       hash_outer_key = sort_array[index]
       Puppet.debug("Converting Hash key #{hash_outer_key} into Array")

       hash_outer_value = my_hash[hash_outer_key]
       my_array_inner = []
       hash_outer_value.map do |key1, value1|
         if ['pwd', 'pass', 'webprofile_settings'].any? {|var| key1.include? var}
           Puppet.debug("Key1: #{key1}, Value1: ****, Class: #{value1.class}")
         else
           Puppet.debug("Key1: #{key1}, Value1: #{value1.inspect}, Class: #{value1.class}")
         end

        if value1.is_a?(Hash)
          str_hash = ""
          value1.map do |k,v|
            str_hash << "#{k}=#{v},"
          end
          str_hash.chomp!(",")
          my_array_inner << "#{key1}=#{str_hash}"
        else
          my_array_inner << "#{key1}=#{value1}"
        end
      end
      my_array_outer << "#{hash_outer_key}=#{my_array_inner.inspect}"
    end
    array_contents = my_array_outer.inspect
    return my_array_outer
  end
end
