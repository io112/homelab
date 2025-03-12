
job "postgres-job" {
  datacenters = ["homelab"]
  type = "service"

  group "postgres" {
    count = 1
    network {
      port "db" {
        to     = 5432
      }
    }

    task "postgres" {
      driver = "docker"
      config {
        image = "postgres"
        ports = ["db"]
      }

      vault {
        policies = ["access-homelab-pg"]
      }

      env {
          POSTGRES_USER="root"
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu = 1000
        memory = 1024
      }

      volume_mount {
        volume      = "postgres-data"
        destination = "/var/lib/postgresql/data"
      }

      template {
        data = <<EOH
        POSTGRES_PASSWORD="{{with secret "providers/data/postgres_homelab"}}{{.Data.data.root_password}}{{end}}"
      EOH

        destination = "secrets/file.env"
        env         = true
      }

      service {
        provider = "nomad"
        name = "postgres"
        port = "db"

        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.csi-controller.rule=HostSNI(`*`)",
          "traefik.tcp.routers.csi-controller.entrypoints=postgres-tcp",
          "traefik.tcp.routers.csi-controller.service=postgres",
        ]

        check {
          name     = "alive"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }

    volume "postgres-data" {
      type      = "csi"
      source    = "postgres-data"
      access_mode = "single-node-writer"
      attachment_mode = "file-system"
      mount_options {
        fs_type     = "nfs"
        mount_flags = ["noatime", "nfsvers=4"]
      }
    }
  }

  update {
    max_parallel = 1
    min_healthy_time = "5s"
    healthy_deadline = "3m"
    auto_revert = false
    canary = 0
  }
}