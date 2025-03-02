job "tunnel" {
  datacenters = ["homelab"]

  type = "service"

  group "tunnel" {
    count = 1

    update {
      max_parallel     = 2
      min_healthy_time = "10s"
      healthy_deadline = "1m"
      progress_deadline = "2m"
      auto_revert = true
    }

    service {
      name     = "tunnel"
      provider = "nomad"
    }

    task "tunnel-task" {
      driver = "docker"

      vault {
        policies = ["access-cf"]
      }

      config {
        image = "cloudflare/cloudflared:latest"
        args = ["tunnel","--no-autoupdate", "run", "--token", "${TUNNEL_TOKEN}"]
      }
      
      template {
        data = <<EOH
        TUNNEL_TOKEN="{{with secret "providers/data/cloudflare"}}{{.Data.data.tunnel_token}}{{end}}"
        EOH

        destination = "secrets/file.env"
        env         = true
      }
    }
  }
  }