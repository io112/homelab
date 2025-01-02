job "terraria" {
    type = "service"

    group "terraria" {
      count = 1
      network {
        port "terraria-game" {
          static = 7777
        }
      }

      service {
        name     = "terraria"
        port     = "terraria-game"
        provider = "nomad"
      }

      task "terraria-task" {
        driver = "docker"
        env {
          WORLD_FILENAME = ocean.hcl
        }

        config {
          image = "ryshe/terraria:latest"
          network_mode = "host"
          args = ["--configFile=/local/traefik.yaml"]
          volumes = [
            "/home/io12/terraria-worlds:/root/.local/share/Terraria/Worlds"
          ]
         }
      }
    }
  }