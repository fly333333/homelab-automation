resource "endpoint" {
    type = string
}

resource "api_token" {
    type = string
    secret = true
    ephemeral = true
}

resource "node" {
    type = string
}

resource "vm_ip" {
    type = string
}

resource "vm_gateway" {
    type = string
}

resource "dns_servers" {
    type = list
}

resource "ssh_public_key" {
    type = string
}

