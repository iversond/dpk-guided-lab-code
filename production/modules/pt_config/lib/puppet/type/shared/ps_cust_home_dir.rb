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

newparam(:ps_cust_home_dir) do
  include EasyType

  desc "Specify the directory where PeopleSoft Customization Home
       (PS_CUST_HOME) is installed.

    This home enables the user to further clarify the ownership
    of files within a PeopleSoft system and separate them for more efficient
    lifecycle maintenance and system administration.

    PS_CUST_HOME enables the user to identify the site's customized files and
    store them in a location separate from the PeopleTools and PeopleSoft
    application files."

  validate do |value|
    unless Puppet::Util.absolute_path?(value)
      fail Puppet::Error, "PS Customization path must be fully qualified, " + \
                          "not '#{value}'"
    end
  end
end
