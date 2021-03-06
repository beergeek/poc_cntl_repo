class profile::mom (
  Hash                  $firewall_rule_defaults,
  String                $autosign_secret,
  Optional[Hash]        $firewall_rules          = {},
  Optional[String]      $eyaml_priv_key          = undef,
  Optional[String]      $eyaml_pub_key           = undef,
  Profile::Cron_h       $backup_cron_hour        = 2,
  Profile::Cron_min     $backup_cron_minute      = 0,
  Profile::Cron_wd      $backup_cron_weekday     = '*',
  String                $autosign_loglevel       = 'INFO',
  String                $autosign_validity       = '7200',
  String                $pe_infra_master         = $server_facts['servername'],
  Boolean               $enable_firewall         = true,
  Boolean               $initial_setup           = false,
  Boolean               $development_env         = true,
  Boolean               $test_env                = true,
  Boolean               $staging_env             = true,
  Optional[String]      $hiera_eyaml_priv        = undef,
  Optional[String]      $hiera_eyaml_pub         = undef,
  Stdlib::Absolutepath  $hiera_eyaml_priv_name   = '/etc/puppetlabs/puppet/ssl/private_key.pkcs7.pem',
  Stdlib::Absolutepath  $hiera_eyaml_pub_name    = '/etc/puppetlabs/puppet/ssl/public_key.pkcs7.pem',
) {

  Pe_hocon_setting {
    ensure => present,
    notify => Service["pe-puppetserver"],
  }

  include puppet_metrics_collector

  augeas { "fileserver.conf-dump":
    changes   => [
      "set /files/etc/puppetlabs/puppet/fileserver.conf/dump/path /opt/dump",
      "set /files/etc/puppetlabs/puppet/fileserver.conf/dump/allow *",
    ],
    incl      => '/etc/puppetlabs/puppet/fileserver.conf',
    load_path => '/opt/puppetlabs/puppet/share/augeas/lenses/dist',
    lens      => 'PuppetFileserver.lns',
  }

  class { 'autosign':
    before   => Exec['setup_autosign'],
  }

  file { ['/opt/dump-staging','/opt/dump']:
    ensure => directory,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0755',
  }

  pe_hocon_setting { 'file-sync.repos.dump.live-dir':
    path    => '/etc/puppetlabs/puppetserver/conf.d/file-sync.conf',
    setting => 'file-sync.repos.dump.live-dir',
    value   => '/opt/dump',
  }

  pe_hocon_setting { 'file-sync.repos.dump.submodules-dir':
    path    => '/etc/puppetlabs/puppetserver/conf.d/file-sync.conf',
    setting => 'file-sync.repos.dump.submodules-dir',
    value   => 'dump',
  }

  pe_hocon_setting { 'file-sync.repos.dump.staging-dir':
    path    => '/etc/puppetlabs/puppetserver/conf.d/file-sync.conf',
    setting => 'file-sync.repos.dump.staging-dir',
    value   => '/opt/dump-staging',
  }

  pe_hocon_setting { 'file-sync.repos.dump.auto-commit':
    path    => '/etc/puppetlabs/puppetserver/conf.d/file-sync.conf',
    setting => 'file-sync.repos.dump.auto-commit',
    value   => true,
  }

  pe_node_group { ['Classification Node Groups', 'Environmental Node Groups']:
    parent          => '00000000-0000-4000-8000-000000000000',
    refresh_classes => true,
    classes         => {},
  }

  if $initial_setup {
    pe_node_group { 'Production environment':
      parent             => 'Environmental Node Groups',
      environment_trumps => true,
      rule               => ["and",["not",["=",["trusted","extensions","pp_environment"],"staging"]],["not",["=",["trusted","extensions","pp_environment"],"test"]],["not",["=",["trusted","extensions","pp_environment"],"development"]]],
      classes            => {},
    }

    if $staging_env {
      pe_node_group { 'Staging environment':
        parent             => 'Environmental Node Groups',
        environment_trumps => true,
        rule               => ["and",["=",["trusted","extensions","pp_environment"],"staging"]],
        classes            => {},
      }
    }

    if $test_env {
      pe_node_group { 'Test environment':
        parent             => 'Environmental Node Groups',
        environment_trumps => true,
        rule               => ["and",["=",["trusted","extensions","pp_environment"],"test"]],
        classes            => {},
      }
    }

    if $development_env {
      pe_node_group { 'Development environment':
        parent             => 'Environmental Node Groups',
        environment_trumps => true,
        rule               => ["and",["=",["trusted","extensions","pp_environment"],"development"]],
        classes            => {},
      }
    }
  }

  pe_node_group { 'Agent-specified environment':
    parent => 'Environmental Node Groups',
  }

  pe_node_group { 'PE Infrastructure':
    parent  => 'Classification Node Groups',
    refresh_classes => false,
    classes => {
      'puppet_enterprise' => {
        'certificate_authority_host' => $pe_infra_master,
        'puppet_master_host'         => $pe_infra_master,
        'console_host'               => $pe_infra_master,
        'puppetdb_host'              => $pe_infra_master,
        'database_host'              => $pe_infra_master,
        'pcp_broker_host'            => $pe_infra_master,
      }
    },
  }

  pe_node_group { 'MoM Server':
    parent             => 'Classification Node Groups',
    pinned             => ['mom.puppet.vm'],
    classes            => {
      role::mom_server => {},
    }
  }

  pe_node_group { 'Com Server':
    parent  => 'Classification Node Groups',
    rule    => ["and",["=",["trusted","extensions","pp_role"],"com_server"]],
    classes => {
      role::com_server => {},
    }
  }

  pe_node_group { 'DB Server':
    parent  => 'Classification Node Groups',
    rule    => ["and",["=",["trusted","extensions","pp_role"],"db_server"]],
    classes => {
      role::db_server => {},
    }
  }

  pe_node_group { 'Web Server':
    parent  => 'Classification Node Groups',
    rule    => ["and",["=",["trusted","extensions","pp_role"],"web_server"]],
    classes => {
      role::web_server => {},
    }
  }

  pe_node_group { 'CD4PE Server':
    parent  => 'Classification Node Groups',
    rule    => ["and",["=",["trusted","extensions","pp_role"],"cd4pe_server"]],
    classes => {
      role::cd4pe_server => {},
    }
  }

  pe_node_group { 'Discovery Server':
    parent  => 'Classification Node Groups',
    rule    => ["and",["=",["trusted","extensions","pp_role"],"discovery_server"]],
    classes => {
      role::discovery_server => {},
    }
  }

  cron { 'puppet_backup':
    ensure  => present,
    command => '/opt/puppetlabs/bin/puppet backup create --scope certs,config,puppetdb',
    user    => 'root',
    weekday => $backup_cron_weekday,
    hour    => $backup_cron_hour,
    minute  => $backup_cron_minute,
  }

  exec { 'setup_autosign':
    command => 'autosign config setup',
    path    => '/opt/puppetlabs/puppet/bin',
    creates => '/etc/puppetlabs/puppetserver/autosign.conf',
  }

  ini_setting {'policy-based autosigning':
    ensure  => present,
    setting => 'autosign',
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'master',
    value   => '/opt/puppetlabs/puppet/bin/autosign-validator',
    require => Exec['setup_autosign'],
  }

  if $enable_firewall {
    if $firewall_rules {
      $firewall_rules.each |String $rule_name, Hash $rule_data| {
        firewall { $rule_name:
          *   => $rule_data;
          default:
            * => $firewall_rule_defaults,
        }
      }
    }
  }

  @@nagios_service { "${facts['fqdn']}_puppet":
    ensure              => present,
    use                 => 'generic-service',
    host_name           => $facts['fqdn'],
    service_description => 'Puppet Master',
    check_command       => 'check_http! -p 8140 -S -u /production/node/test',
    target              => "/etc/nagios/conf.d/${facts['fqdn']}_service.cfg",
    notify              => Service['nagios'],
    require             => File["/etc/nagios/conf.d/${facts['fqdn']}_service.cfg"],
  }


  if $hiera_eyaml_priv and $hiera_eyaml_pub {
    file { $hiera_eyaml_priv_name:
      ensure  => file,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      mode    => '0600',
      content => $hiera_eyaml_priv,
      notify  => Service['pe-puppetserver'],
    }

    file { $hiera_eyaml_pub_name:
      ensure  => file,
      owner   => 'pe-puppet',
      group   => 'pe-puppet',
      mode    => '0600',
      content => $hiera_eyaml_pub,
      notify  => Service['pe-puppetserver'],
    }
  } elsif $hiera_eyaml_priv or $hiera_eyaml_pub {
    fail('Hiera-eyaml requires both the private and public keys')
  }
}

