#
class profile::pipelines (
  Boolean                          $run_artifactory        = false,
  Boolean                          $enable_firewall        = false,
  Array[Enum['pfa','pfc','cd4pe']] $pipeline_type          = ['pfa','pfc','cd4pe'],
  String                           $docker_network_name    = 'pipelines',
  Stdlib::IP::Address::V4::CIDR    $docker_network_subnet  = '192.168.168.0/24',
  Stdlib::IP::Address::Nosubnet    $docker_network_gateway = '192.168.168.1',
  Stdlib::IP::Address::Nosubnet    $master_ip              = '192.168.0.10',
  Stdlib::IP::Address::Nosubnet    $git_server_ip          = '192.168.0.6',
  Stdlib::Host                     $master_fqdn            = 'master.puppet.vm',
  Stdlib::Host                     $git_server_fqdn        = 'bbs.puppet.vm',
  Array[String]                    $pfa_ports              = ['8080:8080','8000:8000','7000:7000'],
  Array[String]                    $pfc_ports              = ['8080:8080','8000:8000','7000:7000'],
  Array[String]                    $cd4pe_ports            = ['8080:8080','8000:8000','7000:7000'],
  Array[String]                    $artifactory_ports      = ['8081:8081'],
  Optional[Array[String]]          $pfa_env_params         = ['USER=pfa',"MYSQL_PWD=P@ssword123", "DB_ENDPOINT=mysql://192.168.0.23:3306/pfa"],
  Optional[Array[String]]          $pfc_env_params         = ['USER=pfc',"MYSQL_PWD=P@ssword123", "DB_ENDPOINT=mysql://192.168.0.23:3306/pfc"],
  Optional[Array[String]]          $cd4pe_env_params       = ['DB_USER=cd4pe','DB_PASS=P@ssword123','DB_ENDPOINT=mysql://192.168.0.23:3306/cd4pe','PFI_SECRET_KEY=g4vmW6D43Qw5CNT+72rBDw==','DUMP_URI=dump://localhost:7000'],
  Optional[Hash]                   $firewall_rules        = undef,
) {

  include profile::docker

  # detach is default in RHEL7, so double detach makes the container fail
  if $facts['os']['family'] == 'RedHat' {
    if $facts['os']['release']['major'] == '7' {
      $detach = undef
    } else {
      $detach = true
    }
  } else {
    $detach = true
  }

  docker_network { $docker_network_name:
    ensure  => present,
    subnet  => $docker_network_subnet,
    gateway => $docker_network_gateway,
  }

  if 'pfc' in $pipeline_type {
    docker::image { 'puppet/pipelines-for-containers':
      tag => 'latest',
    }
    docker::run { 'pfc':
      image                    => 'puppet/pipelines-for-containers:latest',
      detach                   => $detach,
      ports                    => $pfc_ports,
      net                      => $docker_network_name,
      extra_parameters         => [ "--add-host ${master_fqdn}:${master_ip}", "--add-host ${git_server_fqdn}:${git_server_ip}" ],
      remove_container_on_stop => true,
      env                      => $pfc_env_params,
    }

  }
  if 'pfa' in $pipeline_type {
    docker::image { 'puppet/pipelines-for-applications':
      tag => 'latest',
    }
    docker::run { 'pfa':
      image                    => 'puppet/pipelines-for-applications:latest',
      detach                   => $detach,
      ports                    => $pfa_ports,
      net                      => $docker_network_name,
      extra_parameters         => [ "--add-host ${master_fqdn}:${master_ip}", "--add-host ${git_server_fqdn}:${git_server_ip}" ],
      remove_container_on_stop => false,
      env                      => $pfa_env_params,
    }
  }
  if 'cd4pe' in $pipeline_type {
    docker::image { 'puppet/continuous-delivery-for-puppet-enterprise':
      tag => 'latest',
    }
    docker::run { 'cd4pe':
      image                    => 'puppet/continuous-delivery-for-puppet-enterprise:latest',
      detach                   => $detach,
      ports                    => $cd4pe_ports,
      net                      => $docker_network_name,
      remove_container_on_stop => true,
      extra_parameters         => [ "--add-host ${master_fqdn}:${master_ip}", "--add-host ${git_server_fqdn}:${git_server_ip}" ],
      env                      => $cd4pe_env_params,
    }
  }
  if $run_artifactory {
    docker::image { 'docker.bintray.io/jfrog/artifactory-oss':
      tag => '5.8.3',
    }
    docker::run { 'artifactory':
      image                     => 'docker.bintray.io/jfrog/artifactory-oss:5.8.3',
      detach                    => $detach,
      ports                     => $artifactory_ports,
      net                       => $docker_network_name,
      volumes                   => ['data_s3:/var/opt/jfrog/artifactory'],
      remove_container_on_stop  => false,
    }
  }
}
