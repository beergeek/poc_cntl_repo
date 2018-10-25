class role::tomcat_server {

  require profile::base
  include profile::tomcat_services
}
