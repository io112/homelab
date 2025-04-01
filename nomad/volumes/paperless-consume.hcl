id           = "paperless-consume"
namespace    = "default"
name         = "paperless-consume"
type         = "csi"
plugin_id    = "org.democratic-csi.nfs"
capacity_max = "20G"
capacity_min = "1G"

capability {
  access_mode     = "single-node-reader-only"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "single-node-writer"
  attachment_mode = "file-system"
}

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}


mount_options {
  fs_type     = "nfs"
  mount_flags = ["noatime", "nfsvers=4"]
} 