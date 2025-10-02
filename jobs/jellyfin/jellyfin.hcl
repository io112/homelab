job "jellyfin" {
  datacenters = ["homelab"]
  type        = "service"

  group "jellyfin" {
    count = 1

    network {
      port "http" {
        to = 8096
      }
    }

    volume "config" {
      type            = "csi"
      source          = "jellyfin-config"
      access_mode     = "single-node-writer"
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

    volume "dowloads" {
      type            = "csi"
      source          = "torrent-data"
      access_mode     = "multi-node-multi-writer"
      attachment_mode = "file-system"
      mount_options {
        fs_type     = "nfs"
        mount_flags = ["noatime", "nfsvers=4"]
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

    task "jellyfin" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/jellyfin:latest"
        ports = ["http"]
      }

      volume_mount {
        volume      = "config"
        destination = "/config"
        read_only   = false
      }

      volume_mount {
        volume      = "tv"
        destination = "/data/tvshows"
        read_only   = false
      }

      volume_mount {
        volume      = "dowloads"
        destination = "/data/downloads"
        read_only   = false
      }

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "UTC"
      }

      resources {
        cpu    = 300
        memory = 2048
      }

      service {
        name     = "jellyfin"
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
          "traefik.http.routers.jellyfin.rule=Host(`jellyfin.io12.dev`)",
          "traefik.http.routers.jellyfin.entrypoints=websecure",
          "traefik.http.routers.jellyfin.service=jellyfin",
          "traefik.http.routers.jellyfin.tls.certResolver=letsencrypt",
          "traefik.http.services.jellyfin.loadbalancer.server.scheme=http",
        ]
      }
    }
  }
}
