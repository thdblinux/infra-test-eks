module "worknodes" {
  source = "./modulos/worknodes"

}
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_eks_cluster" "eks" {
  name     = "MATRIX-EKS"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = data.aws_subnets.public.ids
  }
}
resource "aws_eks_node_group" "matrix" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "MATRIX-NODE"
  node_role_arn   = aws_iam_role.matrix.arn

  subnet_ids = data.aws_subnets.public.ids
  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  tags = {
    Env = basename(path.cwd)
  }
}