resource "aws_iam_role" "s3_role" {
  name        = format("%s-%s", module.eks_blueprints.eks_cluster_id, "irsa")
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity",
        Effect = "Allow"
        Principal = {
          Federated = module.eks_blueprints.eks_oidc_provider_arn
        }
        Condition = {
          StringLike = {
            "oidc.eks.cn-north-1.amazonaws.com.cn/id/F3FBBFA3747271100017387E04494B5C:sub" = "system:serviceaccount:*"
          }
          StringEquals = {
            "oidc.eks.cn-north-1.amazonaws.com.cn/id/F3FBBFA3747271100017387E04494B5C:aud" = "sts.amazonaws.com"
          }
        }
      },
    ]
  })
}
resource "aws_iam_role_policy" "s3_policy" {
  name = "s3-policy"
  role = aws_iam_role.s3_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
