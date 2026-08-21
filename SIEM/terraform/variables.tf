variable "endpoint" {
    type = string
}

variable "api_token" {
    type = string
    sensitive = true
    ephemeral = true
}

variable "node" {
    type = string
}

variable "vm_ip" {
    type = string
}

variable "vm_gateway" {
    type = string
}

variable "dns_servers" {
    type = list
}

variable "ssh_public_key" {
    type = string
}

