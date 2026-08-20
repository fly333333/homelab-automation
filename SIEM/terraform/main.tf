# Adding provider, data, resource blocks

provider "proxmox" {
  endpoint = var.endpoint
  api_token = var.api_token
  # random_vm_ids = true
  insecure = true
    # Optional: Enable debugging (comment out for production)
  # pm_log_enable = true
  # pm_log_file   = "terraform-plugin-proxmox.log"
  # pm_debug      = true
  # pm_log_levels = {
  #   _default    = "debug"
  #   _capturelog = ""
  # }

  }


resource "proxmox_virtual_environment_vm" "elastic_siem" {
  name      = "elastic-siem"
  node_name = var.node          # must match the Proxmox node name exactly (check in UI/pvecm)
  vm_id     = 201              # any unused ID; explicit is better than letting Proxmox auto-assign

  # Clone from the template you created (VM ID 9000)
  clone {
    vm_id = 9000
    full  = true                # full clone (independent disk), not linked
  }

  cpu {
    cores = 4
    type  = "host"               # passes through host CPU features; better perf than default "kvm64"
  }

  memory {
    dedicated = 13312            # 13GB, matching your earlier sizing plan
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 100           # GB — this resizes the cloned disk up from the template's base size
    file_format  = "qcow2"         # or "qcow2"; raw is typical/faster on local NVMe storage
  }

  network_device {
    bridge = "vmbr0"
  }

  agent {
    enabled = true                # enables QEMU guest agent — needed for Terraform to detect the IP, graceful shutdown, etc.
  }

  initialization {
    datastore_id = "local-lvm"   # where the cloud-init drive itself is stored

    ip_config {
      ipv4 {
        address = var.vm_ip
        gateway = var.vm_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      username = "ansible"
      keys     = [var.ssh_public_key]
    }
  }

  operating_system {
    type = "l26"                  # Linux 2.6+ kernel family — correct for any modern Debian/Ubuntu
  }
}













