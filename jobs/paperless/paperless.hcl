job "paperless" {
    datacenters = ["homelab"]
    type = "service"

    group "paperless" {
        count = 1

        network {
            port "http" {
                to = 8100
            }
            port "tika" {
                to = 9998
            }
            port "gotenberg" {
                to = 3000
            }
        }

        volume "data" {
        type      = "csi"
        source    = "paperless-data"
        access_mode = "single-node-writer"
        attachment_mode = "file-system"
            mount_options {
                fs_type     = "nfs"
                mount_flags = ["noatime", "nfsvers=4"]
            }
        }

        volume "media" {
        type      = "csi"
        source    = "paperless-media"
        access_mode = "single-node-writer"
        attachment_mode = "file-system"
            mount_options {
                fs_type     = "nfs"
                mount_flags = ["noatime", "nfsvers=4"]
            }
        }

        volume "export" {
        type      = "csi"
        source    = "paperless-export"
        access_mode = "single-node-writer"
        attachment_mode = "file-system"
            mount_options {
                fs_type     = "nfs"
                mount_flags = ["noatime", "nfsvers=4"]
            }
        }

        volume "consume" {
        type      = "csi"
        source    = "paperless-consume"
        access_mode = "multi-node-multi-writer"
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

        task "gotenberg" {
            driver = "docker"

            config {
                image = "docker.io/gotenberg/gotenberg:8.7"
                ports = ["gotenberg"]
                command = "gotenberg"
                args = [
                    "--chromium-disable-javascript=true",
                    "--chromium-allow-list=file:///tmp/.*"
                ]
            }

            lifecycle {
                hook = "prestart"
                sidecar = "true"
            }

            resources {
                cpu    = 300
                memory = 256
            }

            service {
                name = "gotenberg"
                port = "gotenberg"
                provider = "nomad"

                check {
                    type     = "http"
                    port     = "gotenberg"
                    path     = "/health"
                    interval = "5s"
                    timeout  = "2s"
                }
            }
        }

        task "tika" {
            driver = "docker"

            config {
                image = "docker.io/apache/tika:latest"
                ports = ["tika"]
            }

            lifecycle {
                hook = "prestart"
                sidecar = "true"
            }

            resources {
                cpu    = 300
                memory = 256
            }

            service {
                name = "tika"
                port = "tika"
                provider = "nomad"

                check {
                    type     = "http"
                    port     = "tika"
                    path     = "/"
                    interval = "5s"
                    timeout  = "2s"
                }
            }
        }

        task "app" {
            driver = "docker"

            vault {
                policies = ["paperless"]
                change_mode   = "restart"
            }
        
            volume_mount {
                volume      = "data"
                destination = "/usr/src/paperless/data"
                read_only   = false
            }
        
            volume_mount {
                volume      = "media"
                destination = "/usr/src/paperless/media"
                read_only   = false
            }

            volume_mount {
                volume      = "export"
                destination = "/usr/src/paperless/export"
                read_only   = false
            }

            volume_mount {
                volume      = "consume"
                destination = "/usr/src/paperless/consume"
                read_only   = false
            }

            config {
                image = "ghcr.io/paperless-ngx/paperless-ngx:2.15.0-beta.rc1"
                ports = ["http"]
            }

            env {
                PAPERLESS_TIKA_ENABLED  = 1
                PAPERLESS_PORT          = 8100
                PAPERLESS_URL           = "https://papers.io12.dev"
            }

            resources {
                cpu    = 300
                memory = 2048
            }

            template {
                data = <<EOH
                PAPERLESS_DBHOST="db.io12.dev"
                PAPERLESS_DBPORT="5432"

                {{ range nomadService "gotenberg" }}
                PAPERLESS_TIKA_GOTENBERG_ENDPOINT=http://{{ .Address }}:{{ .Port }}
                {{ end }}

                {{ range nomadService "tika" }}
                PAPERLESS_TIKA_ENDPOINT=http://{{ .Address }}:{{ .Port }}
                {{ end }}
                
                {{ range nomadService "redis" }}
                PAPERLESS_REDIS="redis://{{ .Address }}:{{ .Port }}"
                {{ end }}

                {{with secret "providers/data/postgres_homelab"}}
                PAPERLESS_DBUSER=root
                PAPERLESS_DBPASS={{.Data.data.root_password}}
                PAPERLESS_DBNAME=paperless
                PAPERLESS_DBSSLMODE=disable
                {{end}}
                EOH

                destination = "secrets/file.env"
                env         = true
            }

            service {
                name = "paperless"
                port = "http"
                provider = "nomad"

                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.paperless.rule=Host(`papers.io12.dev`)",
                    "traefik.http.routers.paperless.entrypoints=websecure",
                    "traefik.http.routers.paperless.service=paperless",
                    "traefik.http.routers.paperless.tls.certResolver=letsencrypt",
                    "traefik.http.services.paperless.loadbalancer.server.scheme=http",
                ]

                check {
                    type     = "http"
                    port     = "http"
                    path     = "/accounts/login/"
                    interval = "5s"
                    timeout  = "2s"
                }

                check_restart {
                    limit           = 15
                    grace           = "120s"
                    ignore_warnings = false
                }
            }
        }
    }
}