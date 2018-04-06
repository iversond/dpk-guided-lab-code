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

newproperty(:ensure) do
  include EasyType

  desc "Whether a service should be running."

  newvalue(:stopped, :event => :service_stopped) do
    provider.stop_domain
  end

  newvalue(:running, :event => :service_started, :invalidate_refreshes => true) do
    provider.start_domain
  end

  aliasvalue(:false, :stopped)
  aliasvalue(:true, :running)

  aliasvalue(:absent, :stopped)
  aliasvalue(:present, :running)

  def retrieve
    provider.status
  end
end
