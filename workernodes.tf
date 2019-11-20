### WORKER NODE SECURITY GROUP

resource "aws_security_group" "cb-node" {
  name        = "dcanadillas-eks-cb-node"
  description = "Security group for all nodes in the cluster"
  # Let's use a conditional identifier. If var.network=true then use the created vpc in networking.tf
  vpc_id = "${var.network}" ? "${aws_vpc.eks-cb[0].id}" : "${var.vpc_id}"
  # vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "dcanadillas-eks-cb-node",
     "kubernetes.io/cluster/${var.cluster-name}", "owned",
    )
  }"
}

resource "aws_security_group_rule" "demo-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.cb-node.id}"
  source_security_group_id = "${aws_security_group.cb-node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "demo-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cb-node.id}"
  source_security_group_id = "${aws_security_group.cb-cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}


### WORKER NODE ACCESS TO EKS MASTER CLUSTER

resource "aws_security_group_rule" "demo-cluster-ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.cb-cluster.id}"
  source_security_group_id = "${aws_security_group.cb-node.id}"
  to_port                  = 443
  type                     = "ingress"
}

### WORKER NODE AUTOSCALING GROUP

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.cloudbees.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

# This data source is included for ease of sample architecture deployment
# and can be swapped out as necessary.
data "aws_region" "current" {}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We implement a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  demo-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.cloudbees.endpoint}' --b64-cluster-ca '${aws_eks_cluster.cloudbees.certificate_authority.0.data}' '${var.cluster-name}'
USERDATA
}

resource "aws_launch_configuration" "cloudbees-demo" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.cb-node.name}"
  image_id                    = "${data.aws_ami.eks-worker.id}"
  # instance_type               = "m4.large"
  instance_type               = "${var.worker_node_type}"
  name_prefix                 = "dcanadillas-eks-cb"
  security_groups             = ["${aws_security_group.cb-node.id}"]
  user_data_base64            = "${base64encode(local.demo-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_autoscaling_group" "cloudbees-demo" {
  desired_capacity     = "${var.num-nodes}"
  launch_configuration = "${aws_launch_configuration.cloudbees-demo.id}"
  max_size             = 4
  min_size             = 0
  name                 = "dcanadillas-eks-cb"
  # vpc_zone_identifier  = flatten(["${aws_subnet.eks-demo.*.id}"])
  # Let's use a conditional identifier. If var.network=true then use the created subnets in networking.tf
  vpc_zone_identifier  = "${var.network}" ? flatten(["${aws_subnet.eks-cb.*.id}"]) : "${var.subnet_id}"
  # vpc_zone_identifier  = "${var.subnet_id}"


  tag {
    key                 = "Name"
    value               = "dcanadillas-eks-cb"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster-name}"
    value               = "owned"
    propagate_at_launch = true
  }
}