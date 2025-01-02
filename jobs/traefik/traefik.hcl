job "traefik" {
    type = "service"

    group "traefik" {
      count = 1
      network {
        port "traefik-ui" {
          static = 8080
        }
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