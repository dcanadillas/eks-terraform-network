### KUBERNETES MASTER IAM ROLE

resource "aws_iam_role" "cb-cluster" {
  name = "dcanadillas-eks-cb-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cb-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.cb-cluster.name}"
}

resource "aws_iam_role_policy_attachment" "cb-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.cb-cluster.name}"
}

### WORKER NODE IAM ROLE AND INSTANCE PROFILE

resource "aws_iam_role" "cb-node" {
  name = "dcanadillas-eks-cb-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cb-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.cb-node.name}"
}

resource "aws_iam_role_policy_attachment" "cb-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.cb-node.name}"
}

resource "aws_iam_role_policy_attachment" "cb-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.cb-node.name}"
}

resource "aws_iam_instance_profile" "cb-node" {
  name = "dcanadillas-eks-cb"
  role = "${aws_iam_role.cb-node.name}"
}
