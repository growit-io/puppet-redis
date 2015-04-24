# This class provides defaults values for parameters of other classes based on
# the operating system.
class redis::params
{
  case $::osfamily {
    'redhat': {
      $packages = ['redis']
      $redis_service = 'redis'
      $sentinel_service = 'sentinel'
      $confdir = '/etc'
    }

    'debian': {
      $packages = ['redis-server', 'redis-tools']
      $redis_service = 'redis-server'
      $sentinel_service = 'redis-sentinel'
      $confdir = '/etc/redis'
    }

    default: {
      fail("unknown operating system family: ${::osfamily}")
    }
  }
}
