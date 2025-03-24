job "gitea" {
    datacenters = ["homelab"]
    type = "service"

    group "gitea" {
        count = 1

        network {
            port "http" {
                to = 3000
            }
        }

        volume "gitea-data" {
        type      = "csi"
        source    = "gitea-data"
        access_mode = "single-node-writer"
        attachment_mode = "file-system"
            mount_options {
                fs_type     = "nfs"
                mount_flags = ["noatime", "nfsvers=4"]
            }
        }

        volume "gitea-config" {
        type      = "csi"
        source    = "gitea-config"
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

            vault {
                policies = ["gitea"]
                change_mode   = "restart"
            }
        
            volume_mount {
                volume      = "gitea-data"
                destination = "/var/lib/gitea"
                read_only   = false
            }
        
            volume_mount {
                volume      = "gitea-config"
                destination = "/etc/gitea"
                read_only   = false
            }

            config {
                image = "gitea/gitea:latest-rootless"
                ports = ["http"]
            }

            env {
                APP_NAME                        = "Gitea: Git with a cup of tea"
                RUN_MODE                        = "prod"
                ROOT_URL                        = "https://git.io12.dev/"
                GITEA__database__DB_TYPE        = "postgres"
            }

            resources {
                cpu    = 200
                memory = 512
            }

            template {
                data = <<EOH
                {{ range nomadService "postgres" }}
                GITEA__database__HOST="{{ .Address }}:{{ .Port }}"
                {{ end }}

                GITEA__database__NAME=gitea

                {{with secret "postgres/creds/gitea-writer"}}
                GITEA__database__USER={{.Data.username}}
                GITEA__database__PASSWD={{.Data.password}}
                {{end}}
                EOH

                destination = "secrets/file.env"
                env         = true
            }

            service {
                name = "gitea"
                port = "http"
                provider = "nomad"

                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.gitea.rule=Host(`git.io12.dev`)",
                    "traefik.http.routers.gitea.entrypoints=websecure",
                    "traefik.http.routers.gitea.service=gitea",
                    "traefik.http.routers.gitea.tls.certResolver=letsencrypt",
                    "traefik.http.services.gitea.loadbalancer.server.scheme=http",
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