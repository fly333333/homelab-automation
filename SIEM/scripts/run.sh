#!/bin/bash

# terraform
cd ../terraform
terraform init --upgrade
terraform plan
terraform apply

# ansible
echo "CHANGE TO PASSWORD" > ~=/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass
cd ../ansible
ansible-playbook -i inventory OS_setup.yml
ansible-playbook -i inventory OS_hardening.yml
ansible-playbook -i inventory EK_install.yml --vault-password-file ~=/.ansible_vault_pass
