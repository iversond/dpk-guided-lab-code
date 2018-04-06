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

newparam(:logoutput) do
  include EasyType

  desc "Whether to log output of the command execution in addition to
    logging the exit code. Defaults to 'on_failure', which only logs the
    output when the command has an exit code that does not match any value
    specified by the 'returns' attribute. As with any resource type, the
    log level can be controlled with the 'loglevel' metaparameter."

    defaultto :on_failure

    newvalues(:true, :false, :on_failure)
end
