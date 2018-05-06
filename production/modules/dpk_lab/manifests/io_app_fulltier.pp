class pt_role::io_app_fulltier inherits pt_role::pt_app_base {

  notify { "Applying pt_role::io_app_fulltier": }

  $ensure   = hiera('ensure')
  $env_type = hiera('env_type')

  if $env_type != 'fulltier' {
    fail('The io_app_fulltier role can only be applied to env_type of fulltier')
  }
  contain ::pt_profile::pt_opa

  if $ensure == present {
    contain ::pt_profile::pt_password
    Class['::pt_profile::pt_system'] ->
    Class['::pt_profile::pt_app_deployment'] ->
    Class['::pt_profile::pt_tools_deployment'] ->
    Class['::pt_profile::pt_oracleserver'] ->
    Class['::pt_profile::pt_psft_environment'] ->
    Class['::pt_profile::pt_psft_db'] ->
    Class['::pt_profile::pt_appserver'] ->
    Class['::pt_profile::pt_prcs'] ->
    Class['::pt_profile::pt_pia'] ->
    Class['::dpk_lab'] ->
    Class['::pt_profile::pt_samba'] ->
    Class['::pt_profile::pt_password'] ->
    Class['::pt_profile::pt_tools_preboot_config'] ->
    Class['::pt_profile::pt_domain_boot'] ->
    Class['::pt_profile::pt_tools_postboot_config'] ->
    Class['::pt_profile::pt_source_details'] ->
    Class['::pt_profile::pt_opa']
  }
  elsif $ensure == absent {
    Class['::pt_profile::pt_opa'] ->
    Class['::pt_profile::pt_source_details'] ->
    Class['::pt_profile::pt_samba'] ->
    Class['::pt_profile::pt_pia'] ->
    Class['::pt_profile::pt_prcs'] ->
    Class['::pt_profile::pt_appserver'] ->
    Class['::pt_profile::pt_psft_db'] ->
    Class['::pt_profile::pt_psft_environment'] ->
    Class['::pt_profile::pt_oracleserver'] ->
    Class['::pt_profile::pt_tools_deployment'] ->
    Class['::pt_profile::pt_app_deployment'] ->
    Class['::pt_profile::pt_system']
  }
  else {
    fail("Invalid value for 'ensure'. It needs to be either 'present' or 'absent'.")
  }
}
