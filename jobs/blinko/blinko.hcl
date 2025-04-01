job "blinko" {
    datacenters = ["homelab"]
    type = "service"

    group "blinko" {
      count = 1
      network {
        port "blinko-ui" {
          to = 1111
        }
      }

      update {
        max_parallel     = 2
        min_healthy_time = "10s"
        healthy_deadline = "1m"
        progress_deadline = "2m"
        auto_revert = true
      }

      volume "blinko-data" {
        type      = "csi"
        source    = "blinko-data"
        access_mode = "single-node-writer"
        attachment_mode = "file-system"
        mount_options {
          fs_type     = "nfs"
          mount_flags = ["noatime", "nfsvers=4"]
        }
      }

      service {
        name     = "blinko"
        port     = "blinko-ui"
        provider = "nomad"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.blinko.rule=Host(`notes.io12.dev`)",
          "traefik.http.routers.blinko.entrypoints=websecure",
          "traefik.http.routers.blinko.service=blinko",
          "traefik.http.routers.blinko.tls.certresolver=letsencrypt",
          "traefik.http.services.blinko.loadbalancer.server.scheme=http",
        ]

        check {
          type     = "http"
          port     = "blinko-ui"
          path     = "/"
          interval = "5s"
          timeout  = "2s"
        }
      }

      task "blinko-task" {
        
        vault {
          policies = ["blinko"]
          change_mode   = "restart"
        }

        driver = "docker"

        volume_mount {
          volume      = "blinko-data"
          destination = "/app/.blinko"
        }

        config {
          image = "blinkospace/blinko:latest"
          ports = ["blinko-ui"]
        }

        env {
          NODE_ENV = "production"
          NEXTAUTH_URL = "https://notes.io12.dev"
          NEXT_PUBLIC_BASE_URL = "https://notes.io12.dev"
        }

        template {
          data = <<EOH
          NEXTAUTH_SECRET="{{with secret "apps/data/blinko_secret"}}{{.Data.data.secret}}{{end}}"
          
          {{ range nomadService "postgres" }}
          DATABASE_URL="{{with secret "postgres/creds/writer"}}postgresql://{{.Data.username}}:{{.Data.password}}{{end}}@{{ .Address }}:{{ .Port }}/blinko"
          {{ end }}
        EOH

          destination = "secrets/file.env"
          env         = true
        }
      }
    }
  }