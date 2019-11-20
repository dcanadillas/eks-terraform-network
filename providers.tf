provider "aws" {
  region                  = "${var.region}"
  shared_credentials_file = "${var.credentials_file}"
  profile                 = "${var.aws_profile}"
}


# This data source is included for ease of sample architecture deployment
# and can be swapped out as necessary.
data "aws_availability_zones" "available" {}