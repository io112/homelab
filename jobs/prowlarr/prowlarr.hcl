job "prowlarr" {
  datacenters = ["homelab"]
  type        = "service"

  group "prowlarr" {
    count = 1

    network {
      port "http" {
        to = 9696
      }
    }

    volume "config" {
      type            = "csi"
      source          = "prowlarr-config"
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

    task "prowlarr" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/prowlarr:latest"
        ports = ["http"]
      }

      volume_mount {
        volume      = "config"
        destination = "/config"
        read_only   = false
      }

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "UTC"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name     = "prowlarr"
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
          "traefik.http.routers.prowlarr.rule=Host(`prowlarr.io12.dev`)",
          "traefik.http.routers.prowlarr.entrypoints=websecure",
          "traefik.http.routers.prowlarr.service=prowlarr",
          "traefik.http.routers.prowlarr.tls.certResolver=letsencrypt",
          "traefik.http.services.prowlarr.loadbalancer.server.scheme=http",
        ]
      }
    }
  }
}