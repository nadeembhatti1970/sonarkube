# ---------------------------------------------------------------------------
# EBS CSI driver identity.
#
# The driver runs as the kube-system/ebs-csi-driver service account and gets
# AWS permissions through EKS Pod Identity (no node-wide permissions, no
# long-lived IRSA tokens). This is what makes SonarQube's gp3 PVC possible.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    sid     = "AllowEksPodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${local.name_prefix}-ebs-csi-driver"
  description        = "EBS CSI driver permissions for the ${local.name_prefix} cluster"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ebs-csi-driver" })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
