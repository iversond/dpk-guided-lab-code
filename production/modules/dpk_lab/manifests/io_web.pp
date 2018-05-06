class dpk_lab::io_web {

  $pia_domain_list = hiera('pia_domain_list')
  $pia_domain_list.each | $domain_name, $pia_domain_info | {

    $site_list = $pia_domain_info['site_list']
    $site_list.each | $site_name, $site_info | {

      $ps_cfg_home = $pia_domain_info['ps_cfg_home_dir']
      $portal_path = "${ps_cfg_home}/webserv/${domain_name}/applications/peoplesoft/PORTAL.war"

      file { "${domain_name}-${site_name-pia-logo}":
        ensure => present,
        path   => "${portal_path}/${site_name}/images/Header.png",
        source => "puppet:///modules/dpk_lab/dpk-lab-logo-${::app}.png",
      }

      $text_properties = $site_info['text_properties']
      $text_properties.each | $key, $value | {
        ini_setting { "${domain_name}-${site_name}-text-${key}":
          ensure            => present,
          path              => "${portal_path}/WEB-INF/psftdocs/${site_name}/text.properties",
          setting           => $key,
          value             => $value,
          key_val_separator => '=',
          section           => '',
        }
      }
    } # end-site

  } # end-pia

}
