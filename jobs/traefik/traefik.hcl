job "traefik" {
  datacenters = ["homelab"]
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
      min_healthy_time = "10s"
      healthy_deadline = "1m"
      progress_deadline = "2m"
      auto_revert = true
    }

    service {
      name     = "traefik"
      port     = "traefik-ui"
      provider = "nomad"
    }

    task "trafik-task" {
      vault {
        policies = ["access-nomad-ro", "access-cf"]
      }

      driver = "docker"

      config {
        image = "traefik:v3.5"
        network_mode = "host"
        args = ["--configFile=/local/traefik.yaml"]
        volumes = ["/opt/acme:/etc/traefik/acme"]
      }

      template {
        destination = "/local/traefik.yaml"
        data = file("./traefik.yaml")
      }

      template {
        destination = "/local/config.yaml"
        data = file("./config.yaml")
      }
      template {
        data = <<EOH
      CF_DNS_API_TOKEN="{{with secret "providers/data/cloudflare"}}{{.Data.data.api_key}}{{end}}"
      EOH

        destination = "secrets/file.env"
        env         = true
      }
    }
  }
}