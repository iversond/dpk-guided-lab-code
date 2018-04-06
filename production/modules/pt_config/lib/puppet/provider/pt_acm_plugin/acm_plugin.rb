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

require 'tempfile'
require 'tmpdir'
require 'etc'
require 'puppet/provider/psae'

Puppet::Type.type(:pt_acm_plugin).provide :acm_plugin, :parent => Puppet::Provider::Psae do
    @acm_prop_file = nil

    mk_resource_methods

   def run_acm_plugin()
     persist_property_file = resource[:persist_property_file]

     @acm_prop_file = create_prop_file()
     Puppet.debug("Phase one property file: #{@acm_prop_file}")

     output, status = run_ae()

     if File.exist?(@acm_prop_file)
       Puppet.debug("PTEM property file #{@acm_prop_file} is present")
     else
       Puppet.debug("PTEM property file #{@acm_prop_file} is absent")
     end
     acm_prop_file_base = File.basename(@acm_prop_file)
     if Facter.value(:osfamily) == 'windows' &&  persist_property_file == true
      FileUtils.copy(@acm_prop_file, Dir.home)
     end
     Puppet.debug("Removing property file #{@acm_prop_file}")
     FileUtils.remove_file(@acm_prop_file, :force => true)
     if status != 0
       Puppet.debug("Phase 1 of AE run failed: #{output}")
       return output, status
     end
     if Facter.value(:osfamily) != 'windows'
       user_home_dir = Etc.getpwnam(resource[:os_user]).dir
       @acm_prop_file = File.join(user_home_dir, "#{acm_prop_file_base}_encrypted")

       Puppet.debug("Phase two property file: #{@acm_prop_file}")
       output, status = run_ae()

       if persist_property_file == false
        Puppet.debug("Removing property file #{@acm_prop_file}")
        FileUtils.remove_file(@acm_prop_file, :force => true)
       end
     end
     return output, status
   end

   private

    def setup_environment()
      env_file_path, cfg_file_path = super()

      case Facter.value(:osfamily)
      when 'windows'
        env_prefix = 'set'
      else
        env_prefix = 'export'
      end
      temp_dir_name = Dir.tmpdir()

      file_prop_dir = File.dirname(@acm_prop_file)
      file_prop = File.basename(@acm_prop_file)

      # add property related environment variables
      open(env_file_path,  'a') do |file_env|
        file_env.puts "#{env_prefix} PS_FILEDIR=#{file_prop_dir}"
        file_env.puts "#{env_prefix} PTEM_PROP=#{file_prop}"
      end
      Puppet.debug(File.read(env_file_path))
      return env_file_path, cfg_file_path
    end

   def create_prop_file
     # genenrate the properties file
     temp_dir_name = Dir.tmpdir()
     rand_num = rand(1000)
     file_prop_path = File.join(temp_dir_name, "ae-ptem-#{rand_num}.prop")
     file_prop = File.open(file_prop_path, 'w')

     if Facter.value(:osfamily) == 'windows'
       file_prop.puts "configure=true"
       file_prop.puts "verify=false"
     else
       file_prop.puts "configure=false"
       file_prop.puts "verify=false"
       file_prop.puts "encrypt_password=true"
     end
     file_prop.puts ""

     plugin_list = resource[:plugin_list]

     plugin_no = 0
     plugin_list.each do |plugin|

       plugin_name = plugin.split('=', 2)[0].strip
       plugin_props = plugin.split('=', 2)[1].strip

       Puppet.debug("Plugin Name: #{plugin_name}, The class of plugin property: #{plugin_props.class}")
       plugin_props.delete!("\n[]\"")
       plugin_props_array = plugin_props.split(", ")

       plugin_name = "#{resource[:program_id]}:#{plugin_name}"

       # check if plugin.name property is given, if so use that as the same of the
       # plugin
       for index in (0...plugin_props_array.length)
         property = plugin_props_array[index]

         name = property.split('=', 2)[0].strip
         if name == 'plugin.name'
           val = property.split('=', 2)[1].strip
           Puppet.debug("Plugin name given as #{val}")
           plugin_name = val
           break
         end
       end
       # check if plugin.run property is given and the value is false, if so
       # do not run the plugin
       plugin_run = true
       for index in (0...plugin_props_array.length)
         property = plugin_props_array[index]

         name = property.split('=', 2)[0].strip
         if name == 'plugin.run'
           val = property.split('=', 2)[1].strip
           Puppet.debug("Plugin run value #{val}")
           plugin_run = val
         end
       end
       if plugin_run == 'false'
         Puppet.debug("Skipping Plugin #{plugin_name}")
         next
       end
       file_prop.puts "plugin.#{plugin_no.to_s}=#{plugin_name}"
       file_prop.puts ""

       for index in (0...plugin_props_array.length)
         property = plugin_props_array[index]

         name = property.split('=', 2)[0].strip
         if name == 'plugin.name'
           next
         end
         val = property.split('=', 2)[1].strip

         if ['pwd', 'pass'].any? {|var| name.include? var}
           Puppet.debug("Found property: #{name}=[****]")
         else
           Puppet.debug("Found property: #{name}=[#{val}]")
         end
         file_prop.puts "#{name}=#{val}"

       end
       plugin_no += 1

       file_prop.puts ""
       file_prop.puts ""
     end
     file_prop.close
     File.chmod(0755, file_prop_path)
     return file_prop_path
   end
end
