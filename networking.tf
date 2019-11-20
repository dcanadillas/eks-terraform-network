### BASE VPC NETWORKING


# # Creating the VPC
resource "aws_vpc" "eks-cb" {
  count = "${var.network}" ? 1 : 0
  cidr_block = "10.0.0.0/16"

  tags = "${
    map(
     "Name", "terraform-eks-cb-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}

# # Creating 2 subnets
resource "aws_subnet" "eks-cb" {
  count = "${var.network}" ? 2 : 0

  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = "${aws_vpc.eks-cb[0].id}"

  tags = "${
    map(
     "Name", "terraform-eks-cb-node",
     "kubernetes.io/cluster/${var.cluster-name}", "shared",
    )
  }"
}



# # Creating the Internet Gateway
resource "aws_internet_gateway" "cloudbees-gw" {
  count = "${var.network}" ? 1 : 0
  vpc_id = "${aws_vpc.eks-cb[0].id}"

  tags = {
    Name = "terraform-eks-cb"
  }
}


# # Now for routes tables and association
resource "aws_route_table" "cloudbees-route" {
  # count = "${var.network}" ? 1 : 0
  vpc_id = "${var.network}" ? "${aws_vpc.eks-cb[0].id}" : "${var.vpc_id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${var.network}" ? "${aws_internet_gateway.cloudbees-gw[0].id}" : "${var.gateway_id}"
  }
}

## If you are using an existing subnet, you should import first the existing route table association
resource "aws_route_table_association" "cloudbees" {
  # count = "${var.network}" ? 2 : 0
  count = 2
  subnet_id      = "${var.network}" ? "${aws_subnet.eks-cb.*.id[count.index]}" : "${var.subnet_id[count.index]}"
  route_table_id = "${aws_route_table.cloudbees-route.id}"
}

