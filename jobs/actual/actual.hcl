job "actual" {
    datacenters = ["homelab"]
    type = "service"

    group "actual" {
        count = 1

        network {
            port "http" {
                to = 5006
            }
        }

        volume "actual-data" {
        type      = "csi"
        source    = "actual-data"
        access_mode = "single-node-writer"
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
            max_parallel = 1
            min_healthy_time = "5s"
            healthy_deadline = "3m"
            auto_revert = false
            canary = 0
        }

        task "app" {
            driver = "docker"
            user = "3000"

            volume_mount {
                volume      = "actual-data"
                destination = "/data"
                read_only   = false
            }
        
            config {
                image = "actualbudget/actual-server:25.8.0"
                ports = ["http"]
            }

            resources {
                cpu    = 500
                memory = 512
            }

            service {
                name = "actual"
                port = "http"
                provider = "nomad"

                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.actual.rule=Host(`budget.io12.dev`)",
                    "traefik.http.routers.actual.entrypoints=websecure",
                    "traefik.http.routers.actual.service=actual",
                    "traefik.http.routers.actual.tls.certResolver=letsencrypt",
                    "traefik.http.services.actual.loadbalancer.server.scheme=http",
                ]

                check {
                    type     = "http"
                    port     = "http"
                    path     = "/"
                    interval = "5s"
                    timeout  = "2s"
                }
            }
        }
    }
}