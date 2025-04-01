job "redis-job" {
  datacenters = ["homelab"]
  type = "service"

  group "redis" {
    count = 1
    network {
      mode = "bridge"
      port "db" {
        to = 6379
      }
    }

    task "redis" {
      driver = "docker"
      user = "3000"
      config {
        image = "redis:7-alpine"
        ports = ["db"]
        command = "redis-server"
        args = [
          "--appendonly", "yes"
        ]
      }

      logs {
        max_files     = 5
        max_file_size = 15
      }

      resources {
        cpu    = 500
        memory = 256
      }

      volume_mount {
        volume      = "redis-data"
        destination = "/data"
      }

      service {
        provider = "nomad"
        name = "redis"
        port = "db"

        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.redis.rule=HostSNI(`*`)",
          "traefik.tcp.routers.redis.entrypoints=redis-tcp",
          "traefik.tcp.routers.redis.service=redis",
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

    volume "redis-data" {
      type      = "csi"
      source    = "redis-data"
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
