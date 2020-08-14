version: '2'
services:
    traefik:
        image: traefik:2.2.8
        tty: true
        stdin_open: true
        ports:
            - ${http_port}:80/tcp
            - ${https_port}:443/tcp
        labels:
            io.rancher.scheduler.global: 'true'
            io.rancher.scheduler.affinity:host_label: ${host_label}
            # Traefik Admin Dashboard
            traefik.version: 2  # TO BE REMOVED AFTER
            traefik.http.routers.api.rule: "Host(`${admin_domain}`)"
            traefik.http.routers.api.service: api@internal
            traefik.http.routers.api.entrypoints: https
            {{- if .Values.auth_users }}
            traefik.http.routers.api.middlewares: auth
            traefik.http.middlewares.auth.basicauth.users: "${auth_users}"
            {{- end }}

        environment:
            # SETTINGS
            TRAEFIK_LOG_LEVEL: DEBUG
            TRAEFIK_GLOBAL_CHECKNEWVERSION: true
            # Traefik Admin Dashboard
            TRAEFIK_API: true
            TRAEFIK_API_INSECURE: true

            # PROVIDERS

            # Rancher
            TRAEFIK_PROVIDERS_RANCHER: true
            TRAEFIK_PROVIDERS_RANCHER_ENABLESERVICEHEALTHFILTER: ${EnableServiceHealthFilter}
            TRAEFIK_PROVIDERS_RANCHER_CONSTRAINTS: Label(`traefik.version`, `2`)  # TO BE REMOVED AFTER

            # CONFIGURATION STORAGE PROVIDERS
            #
            # Note: As of 2.0, the certificates are not stored here.
            #       so HA ssl cert management is not possible anymore.
            #       (they've moved that to EE).
            #
            #       It's a bit useless to use a storage provider, then..
            #
            #   https://community.containo.us/t/traefik-2-2-features/5078/2
            #   https://github.com/containous/traefik/issues/5426
            #

            # Consul
            {{- if .Values.ConsulEndpoint }}
            TRAEFIK_PROVIDERS_CONSUL: true
            TRAEFIK_PROVIDERS_CONSUL_ENDPOINTS: ${ConsulEndpoint}
            # Redis
            # (note: a 'traefik' KEY has to be created manually in redis-cli --> "SET traefik {}")
            {{- else if .Values.RedisEndpoint }}
            TRAEFIK_PROVIDERS_REDIS: true
            TRAEFIK_PROVIDERS_REDIS_ENDPOINTS: ${RedisEndpoint}
            TRAEFIK_PROVIDERS_REDIS_PASSWORD: ${RedisPassword}
            {{- end}}

            # ENTRYPOINTS

            # http
            TRAEFIK_ENTRYPOINTS_HTTP: http
            TRAEFIK_ENTRYPOINTS_HTTP_ADDRESS: ":80"
            TRAEFIK_ENTRYPOINTS_HTTP_HTTP_REDIRECTIONS_ENTRYPOINT_TO: https

            # https
            TRAEFIK_ENTRYPOINTS_HTTPS: https
            TRAEFIK_ENTRYPOINTS_HTTPS_ADDRESS: ":443"
            TRAEFIK_ENTRYPOINTS_HTTPS_HTTP_TLS: true
            TRAEFIK_ENTRYPOINTS_HTTPS_HTTP_TLS_CERTRESOLVER: dns

            # CERTIFICATE RESOLVERS

            # Http Challenge
            TRAEFIK_CERTIFICATESRESOLVERS_HTTP: true
            TRAEFIK_CERTIFICATESRESOLVERS_HTTP_ACME_HTTPCHALLENGE: true
            TRAEFIK_CERTIFICATESRESOLVERS_HTTP_ACME_HTTPCHALLENGE_ENTRYPOINT: https
            TRAEFIK_CERTIFICATESRESOLVERS_HTTP_ACME_EMAIL: ${acme_email}
            TRAEFIK_CERTIFICATESRESOLVERS_HTTP_ACME_STORAGE: traefik/acme/acme.json

            # Wildcard Resolver (Depending on config)
            # Using if/else to decide. Only one is used.
            TRAEFIK_CERTIFICATESRESOLVERS_DNS: true
            TRAEFIK_CERTIFICATESRESOLVERS_DNS_ACME_DNSCHALLENGE: true
            TRAEFIK_CERTIFICATESRESOLVERS_DNS_ACME_DNSCHALLENGE_DELAYBEFORECHECK: 180
            TRAEFIK_CERTIFICATESRESOLVERS_DNS_ACME_EMAIL: ${acme_email}
            TRAEFIK_CERTIFICATESRESOLVERS_DNS_ACME_STORAGE: traefik/acme/acme.json

            # Google
            {{- if .Values.acme_dns_challenge_GCE_PROJECT }}
            TRAEFIK_CERTIFICATESRESOLVERS_DNS_ACME_DNSCHALLENGE_PROVIDER: gcloud
            GCE_PROJECT: ${acme_dns_challenge_GCE_PROJECT}
            GCE_SERVICE_ACCOUNT_FILE: ${acme_dns_challenge_GCE_SERVICE_ACCOUNT_FILE}
            # Cloudflare
            {{- else if .Values.acme_dns_challenge_CF_API_KEY }}
            TRAEFIK_CERTIFICATESRESOLVERS_DNS_ACME_DNSCHALLENGE_PROVIDER: cloudflare
            CF_API_KEY: ${acme_dns_challenge_CF_API_KEY}
            CF_API_EMAIL: ${acme_dns_challenge_CF_API_EMAIL}
            {{- end}}

        volumes:
            - traefik:/traefik/acme
            # - traefik-secrets:/secrets
volumes:
    traefik:
    # traefik-secrets:
    #     driver: rancher-nfs
    #     external: true
