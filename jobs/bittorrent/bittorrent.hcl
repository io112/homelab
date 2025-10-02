job "bittorrent" {
  datacenters = ["homelab"]
  type = "service"

  group "bittorrent" {
    count = 1

    network {
      port "webui" {
        to = 8080
      }
      port "bittorrent" {
        to = 6881
      }
    }

    volume "torrent-data" {
      type      = "csi"
      source    = "torrent-data"
      access_mode = "multi-node-multi-writer"
      attachment_mode = "file-system"
      mount_options {
        fs_type     = "nfs"
        mount_flags = ["noatime", "nfsvers=4"]
      }
    }

    volume "torrent-config" {
      type            = "csi"
      source          = "torrent-config"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
      mount_options {
        fs_type = "nfs"
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

    task "qbittorrent" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/qbittorrent:latest"
        ports = ["webui", "bittorrent"]
      }

      volume_mount {
        volume      = "torrent-data"
        destination = "/downloads"
      }

      volume_mount {
        volume      = "torrent-config"
        destination = "/config"
        read_only   = false
      }

      env {
        PUID       = "1000"
        PGID       = "1000"
        TZ         = "UTC"
        WEBUI_PORT = "8080"
      }

      resources {
        cpu    = 500
        memory = 512
      }

      service {
        name     = "bittorrent"
        port     = "webui"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.torrent.rule=Host(`torrent.io12.dev`)",
          "traefik.http.routers.torrent.entrypoints=websecure",
          "traefik.http.routers.torrent.service=torrent",
          "traefik.http.routers.torrent.tls.certResolver=letsencrypt",
          "traefik.http.services.torrent.loadbalancer.server.scheme=http",
        ]
      }
    }
  }
}