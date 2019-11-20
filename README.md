# EKS Cluster with Terraform and Network selection

This Terraform script will create and deploy an EKS cluster in AWS, regarding the following:

* You can start from scratch, so the script will create VPCs, Subnets, Internet Gateways, AWS instances, etc. required to deploy the K8s cluster with EKS
* You can also choose your existing network objects in AWS (VPCs, Subnets and IGs) by adding their ID in the variables file (`terraform.tfvars`)

To select between two previous options you can use the variable `network` in the `terrraform.tfvars`, or just adding the value as a parameter when applying the terraform plan (`terraform apply -var network=<true|false>`)

## Initialize Terraform

Please, change the template of `terraform.tfvars` included in this repo:

```bash
mv terraform.tfvars_template terraform.tfvars
```

You need to initialize terraform in order to apply the plan to create your EKS cluster.

1. Configure your AWS credentials file (usually in `~/.aws/credentials`)
2. If you need to assume a different role for AWS, you can do it with:
   
    ```bash
    aws sts assume-role --role-arn <the role arn to assume> --role-session-name <a session name>
    ```

    Please, read [AWS documentation about role assignment](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-role.html).

3. Fill the `terraform.tfvars` with the path of your credentials file, the aws profile and the region to use by default (you can fill also the other values to be used later)
4. Initialize your Terraform providers:
   
   ```bash
   terraform init
   ```

## Fill the variables values file

There are different parameters define in the file `terraform.tfvars` to deploy the EKS cluster depending your needs

These are the variables to be used:

* `region`, `credentials_file`, `aws_profile` are just needed from [AWS Provider](https://www.terraform.io/docs/providers/aws/index.html) to authenticate and scope the EKS cluster in AWS
* `cluster-name` The name of your EKS cluster to be used (this would be the name of the cluster when doing a `aws eks list-clusters` from AWS CLI)
* `worker_node_type` The type of the AWS instances regarding sizing to be used by the Kubernetes Worker Nodes
* `num-nodes` Number of Worker Nodes to be used for the cluster
* `network` This parameter just disables the capability of using your own existing network aws infrastructure, like VPCs, Subnets and Gateways. Leave it commented because it is intended to be used when applying the Terraform plan. Default value is `false` 
  * When the value is `true` all the VPC, Subnets, Internet Gateways and route tables will be created for the EKS cluster.
  * When `false`, you need to specify the network components IDs to be used that are already existing in your AWS infrastructure. These are the following parameters in the file.
* `vpc_id` The VPC id to be used (`network = false`)
* `subnet_id` The two subnets IDs to use in a list format (`["subnet1_id", "subnet2_id"]`)
* `gateway_id` The gateway ID is also needed to create the route tables that are going to use

## Option 1 (default): Create the cluster with your own network IDs

This is the default configuration (`network` parameter is set to `false` by default). So in this case you are using your own **VPC**, **Subnets** and **Internet Gateway**. They need to be set in `terraform.tfvars` like:

```tf
vpc_id = "vpc-xxxxxxxxxxxxxxxxx"
subnet_id = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]
gateway_id = "ig-xxxxxxxxxxxxxxxxx"
```

If your existing subnets are already associated with a route table, **you need to import first the existing ones** by:

```bash
terraform import aws_route_table_association.cloudbees[0] subnet-xxxxxxxxxxxxxxxxx/rtb-xxxxxxxxxxxxxx
terraform import aws_route_table_association.cloudbees[1] subnet-xxxxxxxxxxxxxxxxx/rtb-xxxxxxxxxxxxxx
```

> Please, note in this import that the subnet in the first command should be the *subnet1 id* and the second *subnet2 id*

Now you can apply the Terraform plan by (from the root path of this repo folder):

```bash
terraform apply
```

Review the plan shown and type `yes` if you want to create everything:

```
...
      + root_block_device {
          + delete_on_termination = (known after apply)
          + encrypted             = (known after apply)
          + iops                  = (known after apply)
          + volume_size           = (known after apply)
          + volume_type           = (known after apply)
        }
    }

Plan: 10 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_launch_configuration.cloudbees-demo: Creating...
...
```

## Option 2: Create new network components from scratch with Terraform

In this option you don't need to specify any `vpc_id`, `subnet_id` or `gateway_id` in the `terraform.tfvars` file. This is the simplest way to create the cluster, so a new VPC and corresponding Subnetworks will be created in the process of the EKS cluster creation.

Just deploy by:

```bash
terraform apply -var network=true
```

Review the plan shown and type `yes` to confirm:

```
...

Plan: 17 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_launch_configuration.cloudbees-demo: Creating...
...

```

## Configure Kubernetes and attach Worker Nodes to Master

Once the EKS cluster and AWS objects are created and running, you need to attach the Worker Nodes into the Master by deploying a ConfigMap into `kubesystem` namespace.

First, connect to your Kubernetes master with kubectl (Install kubectl CLI tool [here](https://kubernetes.io/docs/tasks/tools/install-kubectl/)). To do that, update your [`kubeconfig` file](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/) with the following `aws`cli command:

```bash
aws eks update-kubeconfig --name <name_of_your_cluster> --alias <your_kubeconfig_name>
```

> NOTE:
> - **<name_of_your_cluster> **would be the same as used in `cluster-name` parameter from `terraform.tfvars` file. You can check your eks clusters with aws cli command: `aws eks list-clusters
> - **<your_kubeconfig_name>** is just an alias to be used when changing different [contexts](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/#define-clusters-users-and-contexts)
> - Please, be sure that you are using the right AWS Role and user from the same credentials used from Terraform script to be able to interact with these commands and K8s cluster

Check that the context is added:

```bash
kubectl config get-contexts
```

The context alias should be shown in the list. And to change to that context:

```bash
kubectl config set-context <the_alias_chosen_before>
```

Now, check that you can list the namespaces in the cluster:

```
kubectl get namespace

NAME              STATUS   AGE
default           Active   5m
kube-node-lease   Active   5m
kube-public       Active   5m
kube-system       Active   5m
```

When the Terraform plan was applied and the cluster created, you should have a command line ouput like the following:

```
Outputs:

config_map_aws_auth = 

apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::xxxxxxxx:role/dddddddddd
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
```

You need to copy the value after `config_map_aws_auth` in a yaml file. You can also do that by: 

```bash
terraform output | awk 'NR> 1 {print $0}' > aws-auth.yaml
```

And now just deploy the ConfigMap:

```bash
kubectl apply -f aws-auth.yaml -n kube-system
```

And you should see now the Worker Nodes attached to the cluster (wait till all of them has the status **"Ready"**, and then CTRL-C to exist the `watch mode`of the command):

```bash
$ kubectl get nodes -w
NAME                         STATUS   ROLES    AGE   VERSION
ip-10-0-2-104.ec2.internal   Ready    <none>   24h   v1.14.7-eks-1861c5
ip-10-0-2-168.ec2.internal   Ready    <none>   24h   v1.14.7-eks-1861c5
ip-10-0-3-203.ec2.internal   Ready    <none>   24h   v1.14.7-eks-1861c5
```

Now, you can enjoy your Kubernetes cluster!

## Disclosure

Just bear in mind that these Terraform scripts are not following the best practices of using [Terraform modules](https://www.terraform.io/docs/modules/index.html). The reason is because this repo is intended to play an understand how Terraform resources are handled for EKS cluster creation. As a Work In Progress repository, some modules could be added in the future.

Enjoy!