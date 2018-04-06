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

require 'etc'
require 'fileutils'
require 'tempfile'
require 'open3'

if Facter.value(:osfamily) == 'windows'
  require 'win32/registry'
end

module PtDeployUtils
  module Validations

    def self.included(parent)
      parent.extend(Validations)
    end

    def validate_user_and_group(user_name, user_group)
      if user_name.nil?
        raise ArgumentError, "deploy_user attribute should be specified for " +
                             "deploying PeopleSoft component on Unix platforms"
      end
      if user_group.nil?
        raise ArgumentError, "deploy_user_group attribute should be specified " +
                       "for deploying a PeopleSoft component on Unix platforms"
      end
    end

    def validate_oracle_inventory(inventory_location,
                                  inventory_user, inventory_group)
      # make sure oracle inventory details are provided
      if inventory_location.nil?
        raise ArgumentError, "oracle_inventory_location attribute should " +
             "be specified for creating Oracle inventory on Unix platforms"
      end
      if inventory_user.nil?
        raise ArgumentError, "oracle_inventory_user attribute should be " +
             "specified for creating Oracle inventory on Unix platforms"
      end
      if inventory_group.nil?
        raise ArgumentError, "oracle_inventory_group attribute should be " +
             "specified for creating Oracle inventory on Unix platforms"
      end
    end

    def check_user_group(user_name, user_group)
      user_info = nil
      group_info = nil
      begin
        user_info = Etc.getpwnam(user_name)
      rescue ArgumentError
        raise ArgumentError, "OS User #{user_name} does not exists"
      end

      begin
        group_info = Etc.getgrnam(user_group)
      rescue ArgumentError
        raise ArgumentError, "OS Group #{value} does not exists"
      end
      user_gid = user_info.gid
      group_gid = group_info.gid
      group_members = group_info.mem

      if (user_gid != group_gid) and
         (group_members.include?(user_name) == false)
        raise ArgumentError, "User #{user_name} does not belong to group " +
                             "#{user_group}"
      end
    end

    def validate_oracle_inventory_permissions(inventory_location,
                                  inventory_user, inventory_group,
                                  deploy_user, deploy_group)
      if File.directory?(inventory_location) == false
        check_user_group(inventory_user, inventory_group)

        if deploy_user != inventory_user
          check_user_group(deploy_user, inventory_group)
        end
      else
        user_id = Etc.getpwnam(inventory_user).uid
        group_id = Etc.getgrnam(inventory_group).gid
        FileUtils.chown_R(user_id, group_id, inventory_location)

        # get the inventory location file ownership
        oracle_inventory_stat = File.stat(inventory_location)

        if deploy_user != inventory_user
          check_user_group(deploy_user, inventory_group)

          # check if group has write permissions to the inventory
          if oracle_inventory_stat.mode & 0070 != 0070
            raise ArgumentError, "The deploy user #{deploy_user} does not have write " +
                 "permission to Oracle inventory #{inventory_location}"

          end
        end
      end
    end

    private

    def get_oracle_inventory
      if Facter.value(:osfamily) == 'windows'
        win_oracle_key = "SOFTWARE\\ORACLE"
        inst_loc_key = "inst_loc"
        begin
          Win32::Registry::HKEY_LOCAL_MACHINE.open(win_oracle_key,
                                  Win32::Registry::KEY_ALL_ACCESS) do |reg|
            begin
              oracle_inv_dir = reg[inst_loc_key]

              oracle_inv_file = File.join(oracle_inv_dir, 'ContentsXML',
                                          'inventory.xml')
              # check if the oracle inventory directory exists
              if File.file?(oracle_inv_file)
                return oracle_inv_dir
              else
                return nil
              end
            rescue
              return nil
            end
          end
        rescue
          return nil
        end
      else
        return nil
      end
    end
  end
end

