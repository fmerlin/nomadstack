#!/usr/bin/bash
if [[ $(groups) == *"docker"* ]]
then
 source /etc/environment.d/docker
fi