# == Class: redis::sentinel
#
# Installs redis if its not already and configures the sentinel settings.
#
# === Parameters
#
# $redis_clusters - This is a hash that defines the redis clusters
# that sentinel should watch.
#
# === Examples
#
# class { 'redis::sentinel': }
#
# redis::sentinel::redis_clusters:
#  'claims':
#    master_ip: '192.168.33.51'
#    down_after: 30000
#    failover_timeout: 180000
#  'monkey':
#    master_ip: '192.168.33.54'
#    down_after: 30000
#    failover_timeout: 180000
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis::sentinel (
  $packages       = $redis::params::packages,
  $version        = 'installed',
  $service        = $redis::params::sentinel_service,
  $redis_clusters = undef,
) inherits redis::params {

  $redis_service = $redis::params::redis_service
  $confdir       = $redis::params::confdir

  # Install the redis package
  ensure_packages($packages, { 'ensure' => $version })

  # On Debian we have to create the redis-sentinel service and make
  # sentinel.conf writable as this isn't handled by the package.
  if $::osfamily == 'debian' {
    file { "/etc/init.d/${service}":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      source  => 'puppet:///modules/redis/redis-sentinel.init',
      require => Package[$packages],
      before  => Service[$service],
    }
  }

  # Declare sentinel.conf here so we can manage ownership
  file { "${confdir}/sentinel.conf":
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package[$packages],
  }

  # Sentinel rewrites its config file so we lay this one down initially.
  # This allows us to manage the configuration file upon installation
  # and then never again.
  file { "${confdir}/sentinel.conf.puppet":
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0644',
    content => template('redis/sentinel.conf.erb'),
    require => Package[$packages],
    notify  => Exec['cp_sentinel_conf'],
  }

  exec { 'cp_sentinel_conf':
    command     => "/bin/cp ${confdir}/sentinel.conf.puppet ${confdir}/sentinel.conf",
    refreshonly => true,
    notify      => Service[$service],
  }

  # Run it!
  service { $service:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package[$packages],
  }

  # Lay down the runtime configuration script
  $config_script = '/usr/local/bin/sentinel_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/sentinel_config.sh.erb'),
    require => Package[$packages],
    notify  => Exec['configure_sentinel'],
  }

  # Apply the configuration. 
  exec { 'configure_sentinel':
    command     => $config_script,
    refreshonly => true,
    require     => [ Service[$service], File[$config_script] ],
  }

}

