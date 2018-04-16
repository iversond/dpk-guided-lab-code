$ps_cfg_home_dir = hiera('ps_config_home')
$ps_cfg_home_dir_norm = normalize_path($ps_cfg_home_dir)

file {"xdo.cfg":
  ensure => file,
  path   => "${ps_cfg_home_dir}/appserv/xdo.cfg",
  content => template('dpk_lab/xdo.cfg.erb'),
}
