# Proxmox Terraform Setup:
## Terraform Service Account:
For background information, Terraform is a Code-as-Infrastructure language/tool, which will allow us to automate deploying VMs with specific configurations. For example, we could have an entire Active Directory domain be automatically deployed within a proxmox datacenter, allowing me to harden or pentest the environment as needed.

To make this possible, we first need to create a "service account" within our proxmox datacenter that has the permissions to deploy what we need. While our root account can do this of course, its good practice for security purposes to have a dedicated account, with dedicated permissions. 

First in Proxmox:
`Datacenter` > `Users` > `Add` 

Next, create the terraform user, these are the settings I added:
- `User name: terraform`
and left the rest blank.

We will then set the permissions for this user:
`Datacenter` > `Roles` > `Create`
`Name: TerraformRole`
I then added the following Privileges (used DatBoy3's blog recommendations):
- `Datastore.Allocate`
- `Datastore.Audit`
- `Mapping.Use`
- `SDN.Use`
- `Sys.Audit`
- `Sys.Console`
- `Sys.Incoming`
- `Sys.Modify`
- `Sys.PowerMgmt`
- `VM.Allocate`
- `VM.Audit`
- `VM.Clone`
- `VM.Config.CDROM`
- `VM.Config.CPU`
- `VM.Config.Cloudinit`
- `VM.Config.Disk`
- `VM.Config.HWType`
- `VM.Config.Memory`
- `VM.Config.Network`
- `VM.Config.Options`
- `VM.GuestAgent.Unrestricted`
- `VM.Migrate`
- `VM.PowerMgmt`

We might need more or less as we go on to deploy, but for now these should work. We can change these in the future, if needed.

Following the role permissions, we need to create a group to host both the terraform user, and the role for it. To do this, 

`Datacenter` > `Groups` > `Create`

Create the group for terraform, which I named `terraform` for simplicity. Then we will click the over-arching `Permissions` tab to `Add` a group permission:

- `Path: /`
- `Group: terraform`
- `TerraformRole`

Then in `Users`, edit the `terraform` user that we created to be added to the `terraform` group. 

The final step is to create an API Token that we will use later with terraform to use the `terraform` account we created. Head to `API Tokens` and click `Add`:

- `User: terraform@pam`
- `Token ID: TerraformToken`
- `Privilege Seperation: Unchecked` (means the token has the same permissions as the user)

##### Create a LXC to Host and Run Scripts
As we now have a dedicated role to use with the terraform/ansible/scripts, we can now create a dedicated box or VM. In a larger environment a bastion would be the ideal (more of a dedicated VM), but for this situation we will just create a LXC. 

To save memory on the tower and for convenience moving forward, we are going to have the control LXC on the mini PC proxmox instead. It will be able to access the terraform user/group we made through its API, servicing as needed. 

*Note:*
*This might be automated in the future, as we can directly create the template in Terraform as well. For now, the template can be created manually.*

To begin, 

Select `Create CT` at the top of proxmox.
- `Hostname` to `control`
- Create and save a strong root password
- Select Debian12 or 13 for CT Templates 
- All the defaults for resources: 8 GiB memory, 1 core, 2048MiB ram + 2048 swap.
- Bridge: `vmbr0`
- Static IP: `[CIDR IP of VM, trivial]`
- Gateway: `[Network gateway ip, not CIDR]`
- Hit `Start` to create it.

Once the container is started, open the console and login as `root` and the password that was set. Next, we'll update and install some of the packages that are needed in the near-future. 

`apt update && apt install -y git curl unzip python3 python3-pip ansible`

Then we follow the steps on https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli to add `terraform` to the lxc. 

After this step, I added a SSH key that I created on the `control` box to  be able to access the repo I am developing in when I am ready to deploy or want to test. Now that we are (mostly) set up, its time to develop. For a better UI/UX experience I will be developing the `terraform` and `ansible` scripts on my local laptop, within a git repo. 

## Additional Setup
Unfortunately we are not quite done yet. To set up for Terraform creating VM's, we need to create a Template that it can pull from (already downloaded and ready). For this step, I used Claude to guide me, which it provides all the shell commands to run on the proxmox host. It essentially downloads a operating system iso straight to storage, then creates a VM, sets a bunch of settings for the VM, cloud initializes it, and converts it into a template. Unfortunately GenAI is not foolproof, so I had to tweak a few things as I went. This step is very doable within the Proxmox UI itself (arguably more straight forward).

The following commands are what I ran, with a few changes from what Claude provided:

```bash
# Had to play around in the Create VM UI to figure out the net0 settings
qm create 9000 --name debian12-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0,firewall=1

cd /var/lib/vz/template/iso

wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2

# Had to run "pvesm status" to make sure I was using the right storage location.
# Pretty obvious in the UI. Also used the full path to the image. 
qm importdisk 9000 /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2 local-lvm

qm set 9000 -scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0

qm set 9000 -boot c -bootdisk scsi0

qm set 9000 --serial0 socket --vga serial0

qm resize 9000 scsi0 +20G

qm set 9000 --ide2 local-lvm:cloudinit

qm template 9000
```
