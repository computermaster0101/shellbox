#!/bin/bash -eux

mkdir /home/ubuntu/.ssh
curl -L -k 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -o /home/ubuntu/.ssh/authorized_keys
chown -R ubuntu /home/ubuntu/.ssh
chmod -R go-rwsx /home/ubuntu/.ssh
