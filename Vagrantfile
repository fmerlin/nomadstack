VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  if Vagrant.has_plugin?("vagrant-proxyconf")
    config.proxy.http     = "http://10.0.2.0:3128/"
    config.proxy.https    = "http://10.0.2.0:3128/"
    config.proxy.no_proxy = "localhost,127.0.0.1,192.168.56.10"
  end
  config.vm.box = "ubuntu/disco64"
  if Vagrant.has_plugin?("vagrant-disksize")
    config.disksize.size = "50GB"
  end
  config.vm.provider :virtualbox do |v|
    v.gui = false
    v.memory = 4096
    v.cpus = 8
    v.customize ["modifyvm", :id, "--nictype1", "virtio"]
  end
  config.vm.provider "hyperv" do |v|
    v.vm_integration_services = {
      guest_service_interface: true,
      CustomVMSRV: true
    }
  end
  config.vm.boot_timeout = 600
  config.vm.hostname = "server1"
  config.vm.network 'private_network', ip: '192.168.56.10'
  config.vm.provision :shell, inline: "echo 'azerty' >/home/vagrant/.vault_pass"
  config.vm.provision "ansible_local" do |ansible|
    ansible.inventory_path = "/vagrant/inventory/local"
    ansible.limit = "all"
    ansible.become = true
    ansible.playbook = "/vagrant/playbooks/nodes/main.yml"
    ansible.config_file = "/vagrant/ansible.cfg"
    ansible.verbose = true
    # ansible.install = true
  end
end
