# ---------------------------------------------------------------------------
# Namespace and storage.
#
# The namespace enforces the "privileged" Pod Security Standard because the
# SonarQube chart's initSysctl container must raise vm.max_map_count and
# fs.file-max inside the pod. Every other control is still applied: workload
# containers run unprivileged, the ServiceAccount token is not mounted
# automatically and the gp3 volume is encrypted by the EBS CSI driver.
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "sonarqube" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/part-of"          = "code-quality-platform"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
  }
}

# ---------------------------------------------------------------------------
# Default gp3 StorageClass backed by the EBS CSI driver installed by core-eks.
# WaitForFirstConsumer keeps the volume in the same AZ as the pod.
# ---------------------------------------------------------------------------
resource "kubernetes_storage_class_v1" "ebs_gp3" {
  metadata {
    name = var.storage_class_name

    annotations = var.set_default_storage_class ? {
      "storageclass.kubernetes.io/is-default-class" = "true"
    } : {}
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  mount_options = ["discard"]
}
