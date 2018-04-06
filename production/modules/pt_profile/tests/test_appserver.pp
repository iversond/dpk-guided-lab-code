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
$appserver_domain_list = hiera('appserver_domain_list')
$appserver_domain_list.each |$domain_name, $appserver_domain| {
  notify {"Setting up Application Server domain ${domain_name}":}

  $feature_settings    = $appserver_domain[feature_settings]
  validate_hash($feature_settings)
  notify {"Feature settings hash: ${feature_settings}\n":}
  $feature_setttings_array = hash_to_array($feature_settings)
  notify {"*** Feature settings ***: [${feature_settings_array}]\n":}

  notify {"*** Feature PUBSUB ***: [${feature_settings['PUBSUB']}]\n":}
}
