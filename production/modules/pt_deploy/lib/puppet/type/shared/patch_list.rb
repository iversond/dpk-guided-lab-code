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

newparam(:patch_list, :array_matching => :all) do
  include EasyType

  desc "Specify  a list of patches pertitent to the component"

  validate do |values|
    values = [values] unless values.is_a? Array
    values.each do |item|
      Puppet.debug("Got patch file : #{item}")

      # check to make sure the patch file is specified as an absolute path
      unless Puppet::Util.absolute_path?(item)
        fail Puppet::Error, "The patch file must be fully qualified, not " + \
                                              "'#{item}'"
      end
      if File.file?(item) == false
        fail Puppet::Error, "The patch file '#{item}' does not exists"
      end
    end
  end
end
