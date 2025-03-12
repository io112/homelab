id           = "postgres-data"
namespace    = "default"
name         = "postgres-data"
type         = "csi"
plugin_id    = "org.democratic-csi.nfs"
capacity_max = "50G"
capacity_min = "5G"

capability {
  access_mode     = "single-node-reader-only"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "nfs"
  mount_flags = ["noatime", "nfsvers=4"]
}
