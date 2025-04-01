job "storage-node" {
    datacenters = ["homelab"]
    type        = "system"

    group "node" {
      update {
        max_parallel     = 2
        min_healthy_time = "10s"
        healthy_deadline = "1m"
        progress_deadline = "2m"
        auto_revert = true
      }

      task "node" {
        driver = "docker"

        vault {
          policies = ["access-csi"]
        }

        config {
          image = "democraticcsi/democratic-csi:latest"

          args = [
            "--csi-version=1.2.0",
            "--csi-name=org.democratic-csi.nfs",
            "--driver-config-file=${NOMAD_TASK_DIR}/driver-config-file.yaml",
            "--log-level=debug",
            "--csi-mode=node",
            "--server-socket=/csi-data/csi.sock",
          ]

          privileged = true
        }

        env {
          NFS_SERVER = "192.168.40.122"
          NFS_SHARE  = "main-zfs/docker-nfs"
          NAS_URL    = "nas.io12.dev"
          CSI_NODE_ID = "${attr.unique.hostname}"
        }

        csi_plugin {
          id        = "org.democratic-csi.nfs"
          type      = "node"
          mount_dir = "/csi-data"
        }

        template {
          destination = "${NOMAD_TASK_DIR}/driver-config-file.yaml"

          data = <<EOH
          driver: freenas-nfs
          instance_id: truenas
          httpConnection:
            protocol: https
            host: {{ env "NAS_URL" }}
            port: 443
            username: {{with secret "providers/data/nas_csi"}}{{.Data.data.http_username}}{{end}}
            password: {{with secret "providers/data/nas_csi"}}{{.Data.data.http_password}}{{end}}
            apiVersion: 2
          sshConnection:
            host: {{ env "NFS_SERVER" }}
            port: 22
            username: {{with secret "providers/data/nas_csi"}}{{.Data.data.ssh_username}}{{end}}
            # use either password or key
            privateKey: {{with secret "providers/data/nas_csi"}}{{.Data.data.ssh_privatekey | toJSON }}{{end}}

          zfs:
            # can be used to override defaults if necessary
            # the example below is useful for TrueNAS 12
            cli:
              sudoEnabled: true
            #
            #  leave paths unset for auto-detection
            #  paths:
            #    zfs: /usr/local/sbin/zfs
            #    zpool: /usr/local/sbin/zpool
            #    sudo: /usr/local/bin/sudo
            #    chroot: /usr/sbin/chroot


            datasetParentName: {{ env "NFS_SHARE" }}/vols
            # do NOT make datasetParentName and detachedSnapshotsDatasetParentName overlap
            # they may be siblings, but neither should be nested in the other
            # do NOT comment this option out even if you don't plan to use snapshots, just leave it with dummy value
            detachedSnapshotsDatasetParentName: {{ env "NFS_SHARE" }}/snaps
            datasetEnableQuotas: true
            datasetEnableReservation: false
            datasetPermissionsMode: "0777"
            datasetPermissionsUser: 0
            datasetPermissionsGroup: 0
            #datasetPermissionsAcls:
            #- "-m everyone@:full_set:allow"
            #- "-m u:kube:full_set:allow"
          nfs:
            shareHost: {{ env "NFS_SERVER" }}
            shareAlldirs: false
            shareAllowedHosts: []
            shareAllowedNetworks: []
            shareMaprootUser: root
            shareMaprootGroup: wheel
            shareMapallUser: ""
            shareMapallGroup: ""
  EOH
        }

        resources {
          cpu    = 500
          memory = 256
        }
      }
    }
  }
