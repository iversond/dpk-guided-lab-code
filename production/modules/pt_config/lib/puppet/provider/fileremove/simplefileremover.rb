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

Puppet::Type.type(:fileremove).provide(:simplefileremover) do

  desc "Removes a file that has already been declared in the catalog"
  ##                   ##
  ## Ensurable Methods ##
  ##                   ##

  def exists?
    if File.exist?(resource[:filename])
      return true
    end
    return false
  end


  def create
    Puppet.debug("Create() #{resource[:filename]}")
  end


  def destroy
    filename = resource[:filename]

    Puppet.debug("Deleting filename #{filename}")
    if File.exist?(filename)
      File.delete(filename)
    end
  end

end
