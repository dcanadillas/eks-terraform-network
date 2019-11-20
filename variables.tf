variable "network" {
    default = "false"
}

variable "vpc_id" {}

variable "subnet_id" {
    type = "list"
}

variable "worker_node_type" {}

variable "num-nodes" {}

variable "region" {}

variable "credentials_file" {}

variable "cluster-name" {}

variable "aws_profile" {}

variable "gateway_id" {}



