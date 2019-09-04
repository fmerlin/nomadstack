#Hashicorp Stack Demo

####! Work in progress !

#### Download and install chocolatey (windows package manager)
   * from [http://chocolatey.org]

#### Download and install VirtualBox
   * from [https://www.virtualbox.org/wiki/Downloads]
   * Make sure Intel VT-x is enabled in the BIOS

    from chocolatey: choco install virtualbox
        or
    from apt: sudo add-apt-repository multiverse && sudo apt-get update && sudo apt install virtualbox

#### Download and install Vagrant
   * from [https://www.vagrantup.com/downloads.html]

    from chocolatey: choco install vagrant
        or
    from apt: sudo apt install vagrant

#### Install plugins from command line
    vagrant plugin install vagrant-ansible-local
    vagrant plugin install vagrant-disksize

#### Start Vagrant from command line
    vagrant up

#### Start a service from commmand line
    vagrant ssh
    ansible-playbook -i inventory/local playbooks/service/<< name of the service >>.yml

where the name of the service can be:

   * elasticsearch: document-oriented database [https://www.elastic.co/guide/index.html]
   * grafana: dashboard [https://grafana.com/docs/]
   * nexus: artifact repository [https://help.sonatype.com/repomanager3]
   * prometheus: TS database for metrics [https://prometheus.io/docs/introduction/overview/]
   * redis: in-memory KV store [https://redis.io/documentation]
   * postgres: SQL database [https://www.postgresql.org/docs/]
   * pgbouncer: connection pooling/load balancer for postgres [https://pgbouncer.github.io/usage.html]
   * openresty: reverse proxy [https://openresty.org/en/]
   * uwsgi: python application server [https://uwsgi-docs.readthedocs.io/en/latest/]
