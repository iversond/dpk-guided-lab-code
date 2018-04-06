/*
 * ***************************************************************
 *  This software and related documentation are provided under a
 *  license agreement containing restrictions on use and
 *  disclosure and are protected by intellectual property
 *  laws. Except as expressly permitted in your license agreement
 *  or allowed by law, you may not use, copy, reproduce,
 *  translate, broadcast, modify, license, transmit, distribute,
 *  exhibit, perform, publish or display any part, in any form or
 *  by any means. Reverse engineering, disassembly, or
 *  decompilation of this software, unless required by law for
 *  interoperability, is prohibited.
 *  The information contained herein is subject to change without
 *  notice and is not warranted to be error-free. If you find any
 *  errors, please report them to us in writing.
 *
 *  Copyright (C) 1988, 2017, Oracle and/or its affiliates.
 *  All Rights Reserved.
 * ***************************************************************
 */
class pt_profile::pt_tools_postboot_config {
  notify { "Applying pt_profile::pt_tools_postboot_config": }

  $env_type           = hiera('env_type')
  if !($env_type in [ 'fulltier', 'midtier']) {
    fail('The pt_tools_postboot_config profile can only be applied to env_type of fulltier or midtier')
  }
  $pshome_hiera       = hiera('ps_home')
  $pshome_location    = $pshome_hiera['location']
  notify {"POST-Boot Tools Config PS Home [${pshome_location}]\n":}

  # check if post-boot config setup needs to be run
  $run_postboot_config_setup  = hiera('run_postboot_config_setup', true)
  if $run_postboot_config_setup == true {
    $component_setup_list      = hiera('component_postboot_setup_list')
    $component_setup_list_keys = keys($component_setup_list)

    $component_setup_order       = hiera('component_postboot_setup_order', '')
    if ($component_setup_order) and ($component_setup_order != '') {
      # validate that the order list matches the keys
      if ! compare_arrays($component_setup_order, $component_setup_list_keys) {
        fail("Component set ordered list do not match the component keys")
      }
      $component_setup_order_list = $component_setup_order
    }
    else {
      # use the retrieved keys to access elements
      $component_setup_order_list = $component_setup_list_keys
    }
    notify {"POST-Boot Using component order list ${component_setup_order_list}":}

    $component_setup_order_list.each |$component_name| {
      notify {"POST-Boot Setting up component ${component_name}":}

      $component_details  = $component_setup_list[$component_name]
      $os_user            = $component_details['os_user']
      $db_settings        = $component_details['db_settings']
      validate_hash($db_settings)
      $db_settings_array  = join_keys_to_values($db_settings, '=')
      notify {"POST-Boot Tools Component ${component_name} config Database settings\n":}

      $run_control_id        = $component_details['run_control_id']
      $persist_property_file = $component_details['persist_property_file']
      if ($persist_property_file) and ($persist_property_file != '') {
        $persist_file = $persist_property_file
      }
      else {
        $persist_file = false
      }

      $acm_plugin_order      = $component_details['acm_plugin_order']
      $acm_plugin_list       = $component_details['acm_plugin_list']
      $acm_plugin_list_keys  = keys($acm_plugin_list)

      if $acm_plugin_order {
        if ! compare_arrays($acm_plugin_order, $acm_plugin_list_keys) {
          fail("ACM plugin ordered list do not match the plugin keys")
        }
        $acm_plugin_array = hash_of_hash_to_array_of_array($acm_plugin_list, $acm_plugin_order)
      }
      else {
        $acm_plugin_array = hash_of_hash_to_array_of_array($acm_plugin_list)
      }
      notify {"POST-Boot Plugin list for component ${component_name}\n":}

      pt_acm_plugin { "postboot_${run_control_id}":
        os_user               => $os_user,
        db_settings           => $db_settings_array,
        run_control_id        => $run_control_id,
        persist_property_file => $persist_file,
        plugin_list           => $acm_plugin_array,
        ps_home_dir           => $pshome_location,
        logoutput             => true,
        loglevel              => debug,
      }
    }
  }
  else {
    notify {"Post-Boot setup run is false":}
  }
}
