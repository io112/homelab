job "traefik" {
    type = "service"

    group "traefik" {
      count = 1
      network {
        port "traefik-ui" {
          static = 8080
        }
      }

      update {
        max_parallel     = 2
        min_healthy_time = "30s"
        healthy_deadline = "5m"
      }

      service {
        name     = "traefik"
        port     = "traefik-ui"
        provider = "nomad"
      }

      task "trafik-task" {
        driver = "docker"

        config {
          image = "traefik:v3.2"
          network_mode = "host"
          args = ["--configFile=/local/traefik.yaml"]
         }
        template {
          destination = "/local/traefik.yaml"
          data = file("./traefik.yaml")
        }
      }
    }
  }