{ config, vars, ... }: let
directories = [
"${vars.serviceConfigRoot}/traefik"
];
files = [
"${vars.serviceConfigRoot}/traefik/acme.json"
];
in
{
  systemd.tmpfiles.rules = 
  map (x: "d ${x} 0775 share share - -") directories ++ map (x: "f ${x} 0600 share share - -") files;
  virtualisation.oci-containers = {
    containers = {
      traefik = {
        image = "traefik";
        autoStart = true;
        cmd = [
          "--api.insecure=true"
          "--providers.docker=true"
          "--providers.docker.exposedbydefault=false"
          "--entrypoints.web.address=:80"
          "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
          "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"
          "--certificatesresolvers.letsencrypt.acme.email=${config.email.toAddress}"
          # HTTP
          "--entrypoints.web.address=:80"
          "--entrypoints.web.http.redirections.entrypoint.to=websecure"
          "--entrypoints.web.http.redirections.entrypoint.scheme=https"
          "--entrypoints.websecure.address=:443"
          # HTTPS
          "--entrypoints.websecure.http.tls=true"
          "--entrypoints.websecure.http.tls.certResolver=letsencrypt"
          "--entrypoints.websecure.http.tls.domains[0].main=${vars.domainName}"
          "--entrypoints.websecure.http.tls.domains[0].sans=*.${vars.domainName}"

        ];
        extraOptions = [
          # Proxying Traefik itslef
          "-l=traefik.enable=true"
          "-l=traefik.http.routers.traefik.rule=Host(`proxy.${vars.domainName}`)"
          "-l=traefik.http.services.traefik.loadbalancer.server.port=8080"
        ];
        ports = [
          "443:443"
        ];
        environmentFiles = [
          config.age.secrets.cloudflareDnsApiCredentials.path
        ];
        volumes = [
          "/var/run/podman/podman.sock:/var/run/docker.sock:ro"
          "${vars.serviceConfigRoot}/traefik/acme.json:/acme.json"
        ];
      };
    };
  };
}
