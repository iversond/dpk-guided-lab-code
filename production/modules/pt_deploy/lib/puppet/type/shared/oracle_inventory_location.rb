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

newparam(:oracle_inventory_location) do
  include EasyType

  desc "*Unix Only* The directory where the Oracle inventory is located."

  validate do |value|
    unless Puppet::Util.absolute_path?(value)
      fail Puppet::Error, "Oracle inventory location must be fully " + \
                          " qualified, not '#{value}'"
    end
    if File.file?(value)
      fail Puppet::Error, "A file exists for the specified Oracle " + \
                          "inventory location #{value}"
    end
  end
end
