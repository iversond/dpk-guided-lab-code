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

require 'fileutils'

module Puppet::Parser::Functions
  newfunction(:get_matched_file, :type => :rvalue, :arity => -3,
              :doc => <<-'ENDHEREDOC') do |args|
    Takes in a directory, and returns a file matching part of the file name.
    ENDHEREDOC

    unless args.first.class == String
      raise ArgumentError, "Wrong argument type: first argument must " + \
                           "be a string"
    end

    search_dir = args[0]
    if FileTest.directory?(search_dir) == false
      return ''
    end

    file_match = args[1]
    unless file_match.is_a?(String)
      raise ArgumentError, "Wrong argument type: second argument must " + \
                           "be a string"
    end
    # get the list of files for the search directory
    dir_entries = Dir.entries(search_dir)

    file_match_reg = Regexp.new("^.*#{file_match}.*$")
    matched_file_list = dir_entries.select { |file|  file[file_match_reg] }

    if matched_file_list.size == 0
      return ''
    end
    if matched_file_list.size > 1
      raise(Puppet::ParseError, "get_matched_file(): More than one file " + \
                                " found matching '#{file_match}' in the " + \
                                "directory '#{search_dir}'")
    end
    File.join(search_dir, matched_file_list[0])

  end
end
