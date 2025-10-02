job "sonarr" {
  datacenters = ["homelab"]
  type        = "service"

  group "sonarr" {
    count = 1

    network {
      port "http" {
        to = 8989
      }
    }

    volume "config" {
      type            = "csi"
      source          = "sonarr-config"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
      mount_options {
        fs_type     = "nfs"
        mount_flags = ["noatime", "nfsvers=4"]
      }
    }

    volume "downloads" {
      type            = "csi"
      source          = "torrent-data"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
      mount_options {
        fs_type     = "nfs"
        mount_flags = ["noatime", "nfsvers=4"]
      }
    }

    volume "tv" {
      type            = "csi"
      source          = "tvshows-data"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
      mount_options {
        fs_type     = "nfs"
        mount_flags = ["noatime", "nfsvers=4", "nolock"]
      }
    }

    restart {
      attempts = 5
      delay    = "30s"
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    task "sonarr" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/sonarr:latest"
        ports = ["http"]
      }

      volume_mount {
        volume      = "config"
        destination = "/config"
        read_only   = false
      }

      volume_mount {
        volume      = "downloads"
        destination = "/downloads"
        read_only   = false
      }

      volume_mount {
        volume      = "tv"
        destination = "/tv"
        read_only   = false
      }

      env {
        TZ   = "UTC"
      }

      resources {
        cpu    = 300
        memory = 1024
      }

      service {
        name     = "sonarr"
        port     = "http"
        provider = "nomad"

        check {
          type     = "http"
          port     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "5s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.sonarr.rule=Host(`sonarr.io12.dev`)",
          "traefik.http.routers.sonarr.entrypoints=websecure",
          "traefik.http.routers.sonarr.service=sonarr",
          "traefik.http.routers.sonarr.tls.certResolver=letsencrypt",
          "traefik.http.services.sonarr.loadbalancer.server.scheme=http",
        ]
      }
    }
  }
}
