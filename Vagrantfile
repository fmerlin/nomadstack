VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
=begin
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http     = "http://192.168.0.2:3128/"
    config.proxy.https    = "http://192.168.0.2:3128/"
    config.proxy.no_proxy = "localhost,127.0.0.1"
  end
=end
  config.vm.box = "ubuntu/disco64"
  config.disksize.size = "50GB"
  config.vm.provider :virtualbox do |v|
    v.memory = 4096
    v.cpus = 2
    v.linked_clone = true
  end
  config.vm.define "server1" do |foobar|
    foobar.vm.hostname = "server1"
    foobar.vm.network 'private_network', ip: '192.168.56.10'
    foobar.vm.provision :shell, inline: "echo 'azerty' > /tmp/vault_pass"
    foobar.vm.provision "ansible_local" do |ansible|
      ansible.inventory_path = "/vagrant/inventory/local"
      ansible.limit = "all"
      ansible.become = true
      ansible.playbook = "/vagrant/playbooks/nodes/all.yml"
      ansible.config_file = "/vagrant/ansible.cfg"
      ansible.verbose = true
      ansible.install = true
    end
  end
end
