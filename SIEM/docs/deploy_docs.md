# Terraform/Ansible/Bash Scripts
For this section I will outline the general setup for these scripts, what they do, and any other relevant information. The goal by the end of this section is to have a bash script that can be run that will deploy and set up the SIEM from the control box. Later, we can use this as a base to deploy more infra, such as the creation and destruction of a test AD Domain.

##### Process

// TODO:
- Process Diagram and Explanation

##### Development Structure
For development, I used an iterative process to cleanly work through developing each script. My approach, as mentioned above, is to combine my learning and AI in a way that does not hinder learning, but increases efficiency developing (*still spending loads of time reading docs...*). 

Additionally, auxillary tools I used include `neovim` as an IDE, `git` for version management, and `obsidian` for documentation/notes. The following steps are the continuous development cycle I used:

1. Research how to do the necessary task (*i.e. Device requirements for ELK stack*).
2. Use AI to assist in planning configuration steps. I explicitly prompt for no code in the output, just steps or commands.
3. Verify AI output via relevant sources (*usually just the docs*)
4. Step through the configuration steps, converting the manual setup to repeatable Bash/Terraform/Ansible scripts. Make sure that these steps follow intentions and accepted security risks.
5. For when idempotecy is needed, the sub-cycle includes:
	- Do initial command, capture `register` and output to `debug`
	- Analyze the output, figure out which variable can be used for checking (i.e. `when`).
	- 
6. Check for syntax or other glaring bugs (*use `--synax-check` in ansible for iterative checking*)
7. At intervals, take a snapshot of the SIEM VM state, then test the script.
8. Bugs that are not easy fixes should use AI to debug. This saves a considerable amount of time, and does not hinder learning. 
9. Reset VM to prior snapshot as needed for testing.
10. After a successful run, manually test the script's efficacy (*i.e. ssh in to the VM and test*). Can be automated down the road.

##### Deployment Structure

To deploy the SIEM, there are a few layers we need to manipulate to successfully automate the process. Firstly, we need to setup and deploy the infrastructure, or in this case, the VM hosting the SIEM. Next we need to change the state of the machine, wether its downloading packages, supplying configuration, or calling APIs. Finally, we have the driving layer, which is in charge of running the two prior layers, removing the need to remember (or potentially mess up) the commands needed. 

To do each of these layers, we have a tool purposed for the layer's goal:

1. **Terraform**
	An Infrastucture-as-Code tool, meant to make deploying cloud or abstracted resources repeatable and easy. For the scope of this SIEM, this means creating a VM with specific requirements to host the SIEM with. 
2. **Ansible**
	This is a IT automation tool for configuration management, application deployment, and task automation. In simpler terms, instead of manually SSHing into a host and configuring a new software, or doing it by a setup script, you create "playbooks" to do tasks for you. 
3. **Bash**
	A scripting language, built to run and enhance linux commands. In this case, it will be used to run the prior two tools, and whatever tasks that need to be done to enable this.

All of these tools combine to make a seamless deploy after key variables are set. Before I dive into the specifics of each layer, lets go over the critical variables that need to be set/understood beforehand:

- `SIEM Host IP`: IP that will be set as the VM's internal networking address.
- `Gateway IP`: The specific upstream address for network traffic.
- `proxmox IP`: The IP of the proxmox node that the VM will be deployed on.
- `proxmox node`: The node that will host the VM. In proxmox terms, this is likely the actual server that hosts proxmox. 
- `Proxmox API Token`: An API token to access an proxmox account that will service the VM. 
- `DNS Servers`: The primary, and backup DNS servers that will be used on the VM.
- `SSH Public Key`: The public key of the device that will be used to run the scripts. This means that a key needs to be generated if its a fresh VM/device. 
- `Elastic Cluster Name`: The name of the entire SIEM.
- `Elastic Node Name`: Name of the SIEM VM or "node" that hosts the SIEM. In this case we are assuming there is only one node in the SIEM.
- `Elastic/Kibana version`: So everything works together seamlessly, set a version of Elastic and Kibana that the SIEM will use. It will not auto-update, which could contain breaking changes and what not. 

The following sections will go through what each step in the scripts are aiming to accomplish and why, then also provide some context on the methods within the tools used. The goal of this is to explain how we are shaping the SIEM and why, and provide all the context needed to be able to read the code. 

*Note: Code examples used to depict an action might not be accurate to what is used at the latest version of the deployment script.*

##### Terraform
As mentioned above, Terraform will be how we deploy the dedicated VM for the ELK stack SIEM. The two main components we are doing in Terraform is setting all the necessary variables for accessing both Proxmox and the VM after its setup, and specifications for the VM. 

Terraform uses its own language ,HashiCorp Configuration Language (HCL), its a human-readable configuration language, almost similar to using json for configuration.  

1. **Terraform Block**
	Focuses on who the providers are for servicing the VM, and what version to use. This allows Terraform to understand how it should setup and interact with said provider (i.e. interact with Proxmox).

2. **Proxmox Provider**
	The provider block in Terraform specifies the access and configuration for using the provider. Common providers other than Proxmox include AWS, Azure, and Google Cloud.

3. **Resource: elastic_siem**
	Resources define VMs or other cloud resources you would like to define and use. You can imagine this is the setup that you do when you select `Create VM` in the Proxmox UI, then go through all the options (i.e. memory, disk space, CPUs, ip config, etc.). For our SIEM, we are dedicating 13GB of RAM and 4 CPU's. 

4. **Variables**
	These store values that are to be used in Terraform Resources. They can be hardcoded, but its usually a better practice to keep them separately. Passwords and keys can be defined as `sensitive` and/or `ephemeral` in order to protect them during the process. In this case, I can also more easily modify them in scripts if they need to change. The variable definitions are stored in `variables.tf` and setting the variables are done in `pmapi.tfvars`. The following code example are a *few* variable definitions:

5. **Running Terraform**
	After you have Terraform installed, you run the following commands to setup Terraform, provide a overview of what will happen, then finally run the terraform script(s).

```bash
terraform init --upgrade
terraform plan
terraform apply
```

##### Ansible
The main goal with ansible is to make the setup of the SIEM as repeatable as possible. Each Ansible Playbook will walk through a series of `tasks` to do a specific action on the SIEM VM. Here are each of the SIEM deploy scripts:

1. **OS_setup**
	Tasks focused on further optimizing the VM for the SIEM.
2. **OS_hardening**
	Adds basic hardening such as setting the firewall, ssh config, fail2ban, and systemlogs.
3. **EK_install**
	The bulk of the tasks for deploying. Downloads and sets up Elastic and Kibana, along with additional tasks. 
4. **ILM_policy**
	Sets the default Index LIfecycle Management.
5. **fleet_server**
	Create and setup the Fleet server, allowing connections to endpoints and endpoint policy management.

###### OS_setup

**Tasks:**

- **Name**: Force Time Sync
	**Goal**: Prevent time issues when downloading with Apt
	**Ansible Module**: `command`

- **Name**: Wait for Sync
	**Goal**: Wait for time sync before moving on to using Apt.
	**Ansible Module**: `command`

- **Name**: Upgrade Package and System
	**Goal**: Make sure the system packages are up-to-date.
	**Ansible Module**: `apt`

- **Name**: Reboot System
	**Goal**: Reboot system to solidify upgraded machine state.
	**Ansible Module**: `reboot`

- **Name**: Increase File Map Parameter
	**Goal**: Elastic accesses many files at one time, so to prevent any file access issues, I change the number of file accessible to much higher than the default
	**Ansible Module**: `template`

- **Name**: Load File Map Kernel Parameter
	**Goal**: The file map parameter is a kernel parameter, meaning we set it when the VM boots in sysctl. To load it immediately, we use `sysctl -p [conf file]` which will set the parameter. 
	**Ansible Module**: `shell`

- **Name**: Turn off Memory Swaps
	**Goal**: As put by the Elastic docs, "Swapping is very bad for performance, for node stability, and should be avoided at all costs." Swaps have less used processes using memory to have their memory stored in disk space. 
	**Ansible Module**: `shell`

- **Name**: Prevent Memory Swaps from Turning Back On
	**Goal**: Modify the `etc/fstab` config file to remove swaps if they exist, preventing the accidental re-enabling of memory swaps. *Used `regex` for this, though a `template` could have worked as well but required more testing on the SIEM VM at the time.*
	**Ansible Module**: `shell`

- **Name**: Increase File and Network Connections
	**Goal**: Want to increase the amount of network connections and processes allowed to be open.
	**Ansible Module**: `template`

- **Name**: Create Directory for System Daemon Service 
	**Goal**: Create the directory where we put the service config for persistent process, file, and memory limit increases. 
	**Ansible Module**: `file`

- **Name**: Set the Service Config
	**Goal**: Inserts the changes in the location we specified earlier, so the process, file and memory limit changes can be made persistently. 
	**Ansible Module**: `template`

###### OS_hardening

- **Name**: Install UFW
	**Goal**: Install UFW, a firewall for unix/linux systems. This will allow us to then set the firewall rules for accessing ports.
	**Ansible Module**: `apt`

- **Name**: Set UFW Default Deny Incoming
	**Goal**: Sets the default rule for incoming traffic to deny. With just this enabled, it would reject all traffic incoming. 
	**Ansible Module**: `ufw`

- **Name**: Set UFW Default Allow Outgoing
	**Goal**: Sets the default rule for outgoing traffic to allow, meaning all traffic can head out. 
	**Ansible Module**: `ufw`

- **Name**: Allow Ports (22, 9200, 9300, 6501, 8220)
	**Goal**: Preumptively set all the allow firewall rules for the SIEM. With these policies in unison, only traffic going to these ports are allowed. 
	**Ansible Module**: `ufw`

- **Name**: Enable UFW
	**Goal**: Actually start the firewall, setting these firewall rules into effect.
	**Ansible Module**: `ufw`

- **Name**: Install Packages for Updates
	**Goal**: Install `unattended-upgrades` and `apt-listchanges` packages to upgrade packages on the system automatically (increasing security). These won't actually upgrade Elastic and Kibana.
	**Ansible Module**: `apt`

- **Name**:  Set the Auto Upgrades
	**Goal**: Enable both packages to be used `Periodically` by `apt`.
	**Ansible Module**: `template`

- **Name**: Set SSH Daemon Config
	**Goal**: Set the configuration for SSH to have more security such as only authenticate with public key. Also sets the use of sftp, which was a retroactive addition as the pipe that ansible was using was throwing warnings later in development.
	**Ansible Module**: `template`

- **Name**: Restart SSHD
	**Goal**: Update the changes we just made to the SSH config.
	**Ansible Module**: `systemd_service`

- **Name**: Install Fail2Ban and Rsyslog
	**Goal**: Download two more packages that will enhance security.
	**Ansible Module**: `apt`

- **Name**: Set Fail2Ban Cofig
	**Goal**: Set the settings for fail2ban. Currently it sets `maxretry` to 5, and `bantime` to 10 minutes. It also stores logins to `/var/log/auth.log`.
	**Ansible Module**: `template`

- **Name**: Start Fail2Ban
	**Goal**: Start fail2ban in systemctl.
	**Ansible Module**: `systemd_service`
###### EK_install
*Note: Some tasks will be combined for brevity.*

- **Name**: Time Sync Again
	**Goal**: Just in-case prior reboots and system changes affected the clock. Critical failure if the time sync is off for Elastic and Kibana `apt` installs.
	**Ansible Module**: `command`

- **Name**: Get elastic install cryptography keys to verify install
	**Goal**: Installation signiture needs to be verified before install.
	**Ansible Module**: `shell`

- **Name**: Signal Signing to Apt
	**Goal**: Apt needs to be aware of the signing before Elastic install.
	**Ansible Module**: `template`

- **Name**: Apt Install Elastic
	**Goal**: Download Elastic via apt, and update the cache before install. 
	**Ansible Module**: `apt`

- **Name**: Configure JVM Heap Size
	**Goal**: JVM heap size is the amount of memory that gets dedicated to the Java Virtual machine, running elasticsearch. This provides the memory for indexing and search operations. The standard memory to allocate is 50% of your total memory for the VM. This means the memory should oscillate between 30% and 70% memory usage, according to the docs. 
	**Ansible Module**: `template`

- **Name**: Set Elastic Search Config
	**Goal**: Using template we want to set the Elastic configuration I want. This sets node name, internal logging location, networking information, being single-node, and all the security and encryption settings needed.
	**Ansible Module**: `template`

- **Name**: Restart System Daemon
	**Goal**: Set up for systemd to run Elastic.
	**Ansible Module**: `systemd_service`

- **Name**: Wait for Elasticsearch to Start
	**Goal**: Give the process some time to setup before continuing with setup.
	**Ansible Module**: `wait_for`

- **Name**: Generate New Elastic Password
	**Goal**: Generate a new elastic superuser password if it is not already defined in Ansible Vault (first time run shouldn't have it).
	**Ansible Module**: `command` and `set_fact`

- **Name**: Add and Encrypt Elastic Password
	**Goal**: Add and encrypt the password to the vault. Stores for future use for Ansible.
	**Ansible Module**: `command` and `blockinfile`

- **Name**: Check If Kibana is Installed 
	**Goal**: Make sure its not installed before installing again. This was more useful during testing, rather than necessary during the full deploy.
	**Ansible Module**: `stat`

- **Name**: Create Enrollment Token for Kibana
	**Goal**: Create a new enrollment token with Elastic to enroll Kibana once its installed. As Kibana is the frontend for Elasticsearch, it needs to be connected.
	**Ansible Module**: `command`

- **Name**: Encrypt and Insert into Vault
	**Goal**: Add the token into the vault encrypted. The token expires in 30 minutes, but will still be stored in the vault for more stable access (versus a environment variable or similar).
	**Ansible Module**: `command`

- **Name**: Install Kibana 
	**Goal**: Apt install Kibana.
	**Ansible Module**: `apt`

- **Name**: Generate Encryption Keys for Kibana
	**Goal**: During testing, there were errors calling the API. After debugging, the security keys need to be generated for Kibana.
	**Ansible Module**: `command` and `set_fact`

- **Name**: Encrypt and Add Keys
	**Goal**: Encrypt and store all the generated encryption keys for later use for Kibana.
	**Ansible Module**: `command`

- **Name**: Add Config File for Kibana
	**Goal**: Sets the Config to the variables we want. This includes the base url, and the encryption keys we just setup to be able to setup Fleet and other API calls. 
	**Ansible Module**: `template`

- **Name**: Enroll Kibana
	**Goal**: Start the `kibana-setup` with the enrollment token, which will make the SIEM UI accessible with the url set. 
	**Ansible Module**: `command`

- **Name**: Start and Enable Kibana
	**Goal**: Start and enable the Kibana service with system daemon
	**Ansible Module**: `systemd_service`

###### ILM_policy

- **Name**: Call the API to Create an ILM Policy
	**Goal**: Create an Index Lifecycle Management which sets how long the indexes will be saved before deletion. 
	**Ansible Module**: `uri`


###### fleet_server

- **Name**: Create Agent Policy for Fleet Server
	**Goal**: Creates a default agent policy for the incoming Fleet Server. Policies for the Fleet Server versus agent are created the same, however, are set as `has_fleet_server`: `true`. 
	**Ansible Module**: `uri`

- **Name**: Create the Fleet Service Token 
	**Goal**: Call the Elastic API to create a service token that the Fleet Server will use to be able to interact with Elastic with. 
	**Ansible Module**: `uri`

- **Name**: Check and Download Elastic Agent
	**Goal**: If Elastic Agent isn't already installed, download it. Agents are how endpoints interact with Elastic.
	**Ansible Module**: `stat` and `unarchive`

- **Name**: Get the Certificate for Elastic
	**Goal**: I need the Elastic certificate to be able to start the Elastic Agent with the API. So we get it from elasticsearch, then clean and save it. 
	**Ansible Module**: `command` and `set_fact`

- **Name**: Install and Start Fleet Server
	**Goal**: Call the elastic API to install the fleet server. Takes the service token, server policy, CA, and the future server port, as inputs. 
	**Ansible Module**: `uri`


#### Resources:
- https://logz.io/learn/complete-guide-elk-stack/#what-elk-stack
- https://www.elastic.co/guide/index.html
- https://medium.com/@DatBoyBlu3/provisioning-proxmox-virtual-machines-with-terraform-d9e9c549f947
- [https://registry.terraform.io/providers/bpg/proxmox/latest/docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs "https://registry.terraform.io/providers/bpg/proxmox/latest/docs")
- [https://developer.hashicorp.com/terraform/language/values/variables#input-variables](https://developer.hashicorp.com/terraform/language/values/variables#input-variables "https://developer.hashicorp.com/terraform/language/values/variables#input-variables")
- [https://developer.hashicorp.com/terraform/language/manage-sensitive-data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data "https://developer.hashicorp.com/terraform/language/manage-sensitive-data")
- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html/managing_monitoring_and_updating_the_kernel/configuring-kernel-parameters-at-runtime_managing-monitoring-and-updating-the-kernel
- https://www.elastic.co/search-labs/blog/elasticsearch-heap-size-jvm-garbage-collection
- https://www.elastic.co/docs/deploy-manage/deploy/self-managed/setup-configuration-memory
- Claude used to debug terraform not reading SSH key properly.
- https://docs.ansible.com/projects/ansible/latest/collections/ansible/
- explainshell.com/
- versionlog.com/elasticsearch
- [https://github.com/elastic/elasticsearch/blob/main/distribution/src/config/elasticsearch.yml](https://github.com/elastic/elasticsearch/blob/main/distribution/src/config/elasticsearch.yml "https://github.com/elastic/elasticsearch/blob/main/distribution/src/config/elasticsearch.yml")
- [https://www.elastic.co/docs/deploy-manage/deploy/self-managed/configure-elasticsearch](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/configure-elasticsearch "https://www.elastic.co/docs/deploy-manage/deploy/self-managed/configure-elasticsearch")
- https://github.com/elastic/kibana/blob/main/config/kibana.yml
- [https://www.elastic.co/docs/reference/fleet](https://www.elastic.co/docs/reference/fleet "https://www.elastic.co/docs/reference/fleet")
- [https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-ilm-put-lifecycle](https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-ilm-put-lifecycle "https://www.elastic.co/docs/api/doc/elasticsearch/operation/operation-ilm-put-lifecycle")
- [https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/uri_module.html#ansible-collections-ansible-builtin-uri-module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/uri_module.html#ansible-collections-ansible-builtin-uri-module "https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/uri_module.html#ansible-collections-ansible-builtin-uri-module")
- https://spacelift.io/blog/ansible-register
- https://spacelift.io/blog/ansible-when-conditional
- https://stackoverflow.com/questions/56663332/what-is-the-difference-between-shell-and-command-in-ansible





