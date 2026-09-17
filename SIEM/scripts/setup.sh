#!/bin/bash



# Terraform Variables
endpoint="[INSERT]"
api_token="[INSERT]"
proxmox_node="[INSERT]"
vm_ip="[INSERT]"
vm_gateway="[INSERT]"
dns_server1="[INSERT]"
dns_server2="[INSERT]"
ssh_public_key="[INSERT]"

# Ansible Variables
ansible_vault_password="[INSERT]"



read -p "Download Ansible and other useful packages (i.e. curl, unzip, python, pip)? [y/n]: " prompt_1
if [[ "$prompt_1" =~ ^[y]$ ]]; then
    apt update && install -y curl unzip python3 python3-pip ansible
fi

read -p "Download Terraform? [y/n]: " prompt_2
if [[ "$prompt_2" =~ ^[y]$ ]]; then
    curl -fsSL [https://apt.releases.hashicorp.com/gpg](https://apt.releases.hashicorp.com/gpg "https://apt.releases.hashicorp.com/gpg") | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
    apt update && apt install terraform
fi


echo "The following prompts will walk through the terraform variables needed."
echo "If the variables were added to the top of the script prior with proper format,"
echo "the prompt will skip."


# proxmox node name
if [$proxmox_node != "[INSERT]"]; then
    read -p "Enter the name of the desired proxmox node" proxmox_node
    echo "Proxmox Node: $proxmox_node"
fi


# proxmox endpoint url
until [[ "$endpoint" =~ ^https://.*$ ]]; do
    read -p "Enter Proxmox Host URL (i.e. https://IP:PORT): " endpoint
done
echo "Enpoint: $endpoint"


# api token for proxmox access
until [[ "$api_token" =~ ^[[:alnum:]_-]+@[[:alnum:]_-]+![[:alnum:]_-]+=[0-9a-fA-F-]+$ ]]; do
    read -p "Paste api token for proxmox: " api_token
done
echo "API Token: $api_token"


# What IP the SIEM will be set to (CIDR notation)
until [[ "$vm_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; do
    read -p "Enter the IP the SIEM will be assigned to: " vm_ip
done
echo "SIEM IP: $vm_ip"


# What IP the network gateway is set to
until [[ "$vm_gateway" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
    read -p "Enter the Network Gateway the SIEM will use (CIDR notation):  " vm_gateway 
done
echo "SIEM IP: $vm_gateway"


# What IP the main DNS server will be set to for SIEM
until [[ "$dns_server1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
    read -p "Enter the main DNS server for the SIEM: " dns_server1
done
echo "Main DNS Server: $dns_server1"


# What IP the backup DNS server will be set to for SIEM
until [[ "$dns_server2" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; do
    read -p "Enter the backup DNS server for the SIEM: " dns_server2
done
echo "Backup DNS Server: $dns_server2"


# Create a SSH Key and Run with SSH agent. If the device doesn't want/need; skip
read -p "Create new SSH_key and start SSH agent? No assumes you have one ready [y/n]: " prompt_2
if [[ "$prompt_2" =~ ^[y]$ ]]; then
    # Can add error handling with `stat` if I want
    key_filename="ansible_ed25519"
    ssh-keygen -t ed25519 -C "ansible" -f "ansible_ed25519"
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/ansible_ed25519.pub
    ssh_public_key=""
    cat ~/.ssh/ansible_ed25519.pub > $ssh_public_key
fi


# The SSH regex, taken from a StackOverflow post :)
# Needs to be referanced in quotes. Hence why its stored in a var
# Regex Source: https://stackoverflow[.]com/questions/70217889/ssh-key-public-regex-validation
ssh_key_regex="^ssh-(rsa|dss|ed25519|ecdsa-sha2-nistp[0-9]+) [A-Za-z0-9+/]+={0,2}( .*|$)$" 
until [[ "$ssh_public_key" =~ $ssh_key_regex ]]; do
    read -p "Paste the ssh_public key of the Ansible control device: " ssh_public_key
done
echo "SSH Public Key: $ssh_public_key"


echo "Creating tfvar file for input variables"

cd ../terraform
cat /dev/null > terraform.tfvars
touch terraform.tfvars
printf "endpoint = \"$endpoint\"\n" >> terraform.tfvars
printf "api_token = \"$api_token\"\n" >> terraform.tfvars
printf "vm_ip = \"$vm_ip\"\n" >> terraform.tfvars
printf "vm_gateway = \"$vm_gateway\"\n" >> terraform.tfvars
printf "dns_servers = [\"$dns_server1\", \"$dns_server2\"]\n" >> terraform.tfvars
printf "ssh_public_key = \"$ssh_public_key\"\n" >> terraform.tfvars














# Create the Ansible Vault Password for accessing Vault and SIEM Secrets
if [$ansible_vault_password != "[INSERT]"]; then
    read -p "Enter new Ansible Vault Password (used for SIEM secrets): " ansible_vault_password
    echo "Ansible Vault Password: $ansible_vault_password"
    touch ~/.ansible_vault_pass
    echo "$ansible_vault_password" > ~/.ansible_vault_pass
fi


