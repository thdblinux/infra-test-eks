resource "aws_eks_node_group" "matrix" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "MATRIX-NODE"
  node_role_arn   = aws_iam_role.matrix.arn
  instance_types = ["t3.medium"]

  subnet_ids = data.aws_subnets.public.ids
  scaling_config {
    desired_size = var.worknode_desired_size
    max_size     = var.worknode_max_size
    min_size     = var.worknode_min_size
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.matrix-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.matrix-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.matrix-AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.matrix-AmazonEBSCSIDriverPolicy,
    aws_eks_cluster.eks
  ]
}