### K8s MASTER CLUSTER SECURITY GROUP

resource "aws_security_group" "cb-cluster" {
  name        = "dcanadillas-eks-cb-cluster"
  description = "Cluster communication with worker nodes"
  # Let's use a conditional identifier. If var.network=true then use the created vpc in networking.tf
  vpc_id = "${var.network}" ? "${aws_vpc.eks-cb[0].id}" : "${var.vpc_id}"
  # vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dcanadillas-eks-cb"
  }
}

# # OPTIONAL: Allow inbound traffic from your local workstation external IP
# #           to the Kubernetes. You will need to replace A.B.C.D below with
# #           your real IP. Services like icanhazip.com can help you find this.
# resource "aws_security_group_rule" "demo-cluster-ingress-workstation-https" {
#   cidr_blocks       = ["88.1.23.151/32"]
#   description       = "Allow workstation to communicate with the cluster API Server"
#   from_port         = 443
#   protocol          = "tcp"
#   security_group_id = "${aws_security_group.demo-cluster.id}"
#   to_port           = 443
#   type              = "ingress"
# }


### K8s EKS MASTER

resource "aws_eks_cluster" "cloudbees" {
  name            = "${var.cluster-name}"
  role_arn        = "${aws_iam_role.cb-cluster.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.cb-cluster.id}"]
    # subnet_ids         = flatten(["${aws_subnet.eks-cb.*.id}"])
    # Let's use a conditional identifier. If var.network=true then use the created subnets in networking.tf
    subnet_ids  = "${var.network}" ? flatten(["${aws_subnet.eks-cb.*.id}"]) : "${var.subnet_id}"
    # subnet_ids         = "${var.subnet_id}"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cb-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cb-cluster-AmazonEKSServicePolicy",
  ]
}