#!/bin/bash

# terraform
cd ../terraform
terraform init --upgrade
terraform plan
terraform apply

# ansible
cd ../ansible
ansible-playbook -i inventory OS_setup.yml
ansible-playbook -i inventory OS_hardening.yml
