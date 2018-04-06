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
  newfunction(:normalize_path, :type => :rvalue, :arity => 1,
                               :doc => <<-'ENDHEREDOC') do |args|
      Takes in a string, and returns a string normalized to the os path
    ENDHEREDOC

    unless args[0].class == String
      raise ArgumentError, "Wrong argument type: argument must " + \
                           "be a string"
    end

    norm_path = args[0]
    if lookupvar('osfamily') == 'windows'
      norm_path = norm_path.gsub('/', '\\')
    end
    Puppet.debug("Normalized path: #{norm_path}")
    norm_path
  end
end
