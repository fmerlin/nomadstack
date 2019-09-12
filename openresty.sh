#!/usr/bin/bash
nomad stop openresty
docker rm $(docker ps -aq)
docker rmi nexus.service.consul:5000/paas/openresty:v1
sudo rm /var/log/fluentbit/*
ansible-playbook -i inventory/local playbooks/services/openresty.yml
