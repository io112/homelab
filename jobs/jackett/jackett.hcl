job "jackett" {
  datacenters = ["homelab"]
  type        = "service"

  group "jackett" {
    count = 1

    network {
      port "http" {
        to = 9117
      }
    }

    volume "config" {
      type            = "csi"
      source          = "jackett-config"
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

    task "jackett" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/jackett:latest"
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

      env {
        TZ   = "UTC"
      }

      resources {
        cpu    = 300
        memory = 1024
      }

      service {
        name     = "jackett"
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
          "traefik.http.routers.jackett.rule=Host(`jackett.io12.dev`)",
          "traefik.http.routers.jackett.entrypoints=websecure",
          "traefik.http.routers.jackett.service=jackett",
          "traefik.http.routers.jackett.tls.certResolver=letsencrypt",
          "traefik.http.services.jackett.loadbalancer.server.scheme=http",
        ]
      }
    }
  }
}
