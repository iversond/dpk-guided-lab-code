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

module Puppet
  Type.newtype(:pt_ulimit_entry) do

    @doc = "Adds or deletes Linux ulimit entry."

    validate do
      #  the type applies to only Linux platform
      if Facter.value(:kernel) != 'Linux'
        fail("This resource is applicable to Linux systems only")
      end

      # make sure domain is specified
      if self[:ulimit_domain].nil?
        fail("ulimit_domain should be specified for ulimit entry")
      end

      # make sure type is specified
      if self[:ulimit_type].nil?
        fail("ulimit_type should be specified for ulimit entry")
      end
      #
      # make sure item is specified
      if self[:ulimit_item].nil?
        fail("ulimit_item should be specified for ulimit entry")
      end

      # make sure value is specified
      if self[:ulimit_value].nil?
        fail("ulimit_value should be specified for ulimit entry")
      end
    end

    ensurable

    newparam(:name, :namevar => true) do
      desc "The name of the ulimit entry."
    end

    newparam(:ulimit_domain) do
      desc "Specifies the name of the ulimit entry.
        <domain> can be:
              - an user name
              - a group name, with @group syntax
              - the wildcard *, for default entry
              - the wildcard %, can be also used with %group syntax,
                for maxlogin limit"
    end

    newparam(:ulimit_type) do
      desc "Specify the type of the ulimit entry.
        <type> can have the two values:
              - \"soft\" for enforcing the soft limits
              - \"hard\" for enforcing hard limits"
      newvalues(:soft, :hard)
    end

    newparam(:ulimit_item) do
      desc "Specifies the item of the ulimit entry.
        <item> can be one of the following:
              - core - limits the core file size (KB)
              - data - max data size (KB)
              - fsize - maximum filesize (KB)
              - memlock - max locked-in-memory address space (KB)
              - nofile - max number of open files
              - rss - max resident set size (KB)
              - stack - max stack size (KB)
              - cpu - max CPU time (MIN)
              - nproc - max number of processes
              - as - address space limit
              - maxlogins - max number of logins for this user
              - maxsyslogins - max number of logins on the system
              - priority - the priority to run user process with
              - locks - max number of file locks the user can hold
              - sigpending - max number of pending signals
              - msgqueue - max memory used by POSIX message queues (bytes)
              - nice - max nice priority allowed to raise to
              - rtprio - max realtime priority"

      newvalues(:core, :data, :fsize, :memlock, :nofile, :rss, :stack,
                :cpu, :nproc, :as, :maxlogins, :maxsyslogins, :priority,
                :locks, :sigpending, :msgqueue, :nice, :rtprio)

    end

    newproperty(:ulimit_value) do
      desc "Specifies the value of the ulimit entry."
    end
  end
end
