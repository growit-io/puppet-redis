# == Class: redis
#
# Installs and configures redis.
#
# === Parameters
#
# $config: A hash of Redis config options to apply at runtime
# $manage_persistence: Boolean flag for including the redis::persist class
# $slaveof: IP address of the initial master Redis server 
# $version: The package version of Redis you want to install 
#
# === Examples
#
# $config_hash = { 'dir' => '/pub/redis', 'maxmemory' => '1073741824' }
#
# class { redis:
#   config  => $config_hash
#   slaveof => '192.168.33.10'
# }
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis (
  $config             = {},
  $manage_persistence = false,
  $slaveof            = undef,
  $bind               = '*',
  $packages           = $redis::params::packages,
  $version            = 'installed',
  $service            = $redis::params::redis_service,
) inherits redis::params {

  $confdir = $redis::params::confdir

  # Install the redis package
  ensure_packages($packages, { 'ensure' => $version })

  # Define the data directory with proper ownership if provided
  if ! empty($config['dir']) {
    file { $config['dir']:
      ensure  => directory,
      owner   => 'redis',
      group   => 'redis',
      require => Package[$packages],
      before  => Exec['configure_redis'],
    }
  }

  # Declare redis.conf so that we can manage the ownership
  file { "${confdir}/redis.conf":
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package[$packages],
  }

  # Lay down intermediate config file and copy it in with a 'cp' exec resource.
  # Redis rewrites its config file with additional state information so we only
  # want to do this the first time redis starts so we can at least get it 
  # daemonized and assign a master node if applicable.
  file { "${confdir}/redis.conf.puppet":
    ensure  => present,
    owner   => redis,
    group   => root,
    mode    => '0644',
    content => template('redis/redis.conf.puppet.erb'),
    require => Package[$packages],
    notify  => Exec['cp_redis_config'],
  }

  exec { 'cp_redis_config':
    command     => "/bin/cp -p ${confdir}/redis.conf.puppet ${confdir}/redis.conf",
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

  # Lay down the configuration script,  Content based on the config hash.
  $config_script = '/usr/local/bin/redis_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/redis_config.sh.erb'),
    require => Package[$packages],
    notify  => Exec['configure_redis'],
  }
    
  # Apply the configuration. 
  exec { 'configure_redis':
    command     => $config_script,
    refreshonly => true,
    require     => [ Service[$service], File[$config_script] ],
  }

  # In an HA setup we choose to only persist data to disk on
  # the slaves for better performance.
  if $manage_persistence {
    include redis::persist
  }

}
