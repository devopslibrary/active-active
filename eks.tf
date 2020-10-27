# 2 EKS Clusters, one in Virginia, one in Ohio

# Virginia EKS Cluster
data "aws_eks_cluster" "cluster-virginia" {
  name = module.eks-virginia.cluster_id
  provider      = aws.virginia
}

data "aws_eks_cluster_auth" "cluster-virginia" {
  name = module.eks-virginia.cluster_id
  provider      = aws.virginia
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster-virginia.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster-virginia.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster-virginia.token
  load_config_file       = false
  version                = "~> 1.9"
  alias = "virginia"
}

module "eks-virginia" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_version = "1.18"
  version      = "13.0.0"
  cluster_name = "virginia-cluster"
  vpc_id       = module.virginia-vpc.vpc_id
  subnets      = concat(module.virginia-vpc.private_subnets, module.virginia-vpc.public_subnets)
  enable_irsa  = true
  workers_group_defaults = {
    subnets = module.virginia-vpc.private_subnets
  }
  worker_groups = [
    {
      instance_type = "t3a.medium"
      asg_max_size  = 4
      asg_min_size  = 2
      asg_desired_capacity = 2
    }
  ]
  providers = {
    aws = aws.virginia
    kubernetes = kubernetes.virginia
  }
  worker_additional_security_group_ids = [aws_security_group.allow-traffic-from-ohio-vpc.id]
}

# Ohio EKS Cluster
data "aws_eks_cluster" "cluster-ohio" {
  name = module.eks-ohio.cluster_id
  provider      = aws.ohio
}

data "aws_eks_cluster_auth" "cluster-ohio" {
  name = module.eks-ohio.cluster_id
  provider      = aws.ohio
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster-ohio.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster-ohio.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster-ohio.token
  load_config_file       = false
  version                = "~> 1.9"
  alias = "ohio"
}

module "eks-ohio" {
  source       = "terraform-aws-modules/eks/aws"
  cluster_version = "1.18"
  version      = "13.0.0"
  cluster_name = "ohio-cluster"
  vpc_id       = module.ohio-vpc.vpc_id
  subnets      = concat(module.ohio-vpc.private_subnets, module.ohio-vpc.public_subnets)
  enable_irsa  = true
  workers_group_defaults = {
    subnets = module.ohio-vpc.private_subnets
  }
  worker_groups = [
    {
      instance_type = "t3a.medium"
      asg_max_size  = 4
      asg_min_size  = 2
      asg_desired_capacity = 2
    }
  ]
  providers = {
    aws = aws.ohio
    kubernetes = kubernetes.ohio
  }
  worker_additional_security_group_ids = [aws_security_group.allow-traffic-from-virginia-vpc.id]
}
