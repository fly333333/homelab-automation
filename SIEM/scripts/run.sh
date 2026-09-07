#!/bin/bash

# terraform
# cd ../terraform
# terraform init --upgrade
# terraform plan
# terraform apply

# ansible
# echo "CHANGE TO PASSWORD" > ~=/.ansible_vault_pass
# chmod 600 ~/.ansible_vault_pass

# clear out the vault, so the fresh passwords can be added.
cd ../ansible
true > group_vars/siem/vault.yml
# ansible-playbook -i inventory OS_setup.yml
# ansible-playbook -i inventory OS_hardening.yml
ansible-playbook -i inventory EK_install.yml --vault-password-file ~/.ansible_vault_pass
ansible-playbook -i inventory fleet_server.yml --vault-password-file ~/.ansible_vault_pass


# TODO:
# - Input for SIEM IP. Copies to vars.yml
# - Option to output elastic credentials to screen after SIEM deploy.
