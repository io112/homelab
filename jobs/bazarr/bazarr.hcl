job "bazarr" {
  datacenters = ["homelab"]
  type        = "service"

  group "bazarr" {
    count = 1

    network {
      port "http" {
        to = 6767
      }
    }

    volume "config" {
      type            = "csi"
      source          = "bazarr-config"
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

    task "bazarr" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/bazarr:latest"
        ports = ["http"]
      }

      volume_mount {
        volume      = "config"
        destination = "/config"
        read_only   = false
      }

      volume_mount {
        volume      = "tv"
        destination = "/tv"
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
        name     = "bazarr"
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
          "traefik.http.routers.bazarr.rule=Host(`bazarr.io12.dev`)",
          "traefik.http.routers.bazarr.entrypoints=websecure",
          "traefik.http.routers.bazarr.service=bazarr",
          "traefik.http.routers.bazarr.tls.certResolver=letsencrypt",
          "traefik.http.services.bazarr.loadbalancer.server.scheme=http",
        ]
      }
    }
  }
}
