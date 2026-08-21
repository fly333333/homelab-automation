#!/bin/bash

cd ../terraform
terraform init --upgrade
terraform plan
# terraform apply
