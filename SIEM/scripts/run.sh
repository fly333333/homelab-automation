#!/bin/bash

# terraform
cd ../terraform
terraform init --upgrade
terraform plan
terraform apply

# ansible
cd ../ansible
PUBLIC_IP=192.168.0.15 # IP is hardcoded in terraform. Can change later.
ansible-playbook --check OS_setup.yml
ansible-playbook --check OS_hardening.yml
