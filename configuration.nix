# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, vars, lib, pkgs, ... }:

let
    domainName = "paradoz.fr";
    timeZone = "Europe/Paris";
    email.toAddress = "nicolas.bouzin@tutanota.com";
    serviceConfigRoot = "/root";
    directories = [ "$serviceConfigRoot/traefik" ];
    files = [ "$serviceConfigRoot/traefik/acme.json" ];
in 
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  
  hardware.cpu.intel.updateMicrocode = true;
  system.autoUpgrade.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking.hostName = "nixos"; # Define your hostname.
  networking.wireless.enable = false;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.useDHCP = false;

  networking.interfaces.enp3s0.ipv4.addresses = [ {
    address = "192.168.1.3";
    prefixLength = 24;
  } ];

  networking.nameservers = [ "192.168.1.254" ];
  networking.defaultGateway = "192.168.1.254";

  time.timeZone = "Europe/Paris";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "fr_FR.UTF-8";
  console = {
   font = "Lat2-Terminus16";
   keyMap = "fr";
   useXkbConfig = false; # use xkb.options in tty.
  };


  # Configure keymap in X11
  services.xserver.xkb.layout = "fr";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  users.users.nicolas = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    glances
    podman
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };


  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFsT6NKBg9I/+r5SjXt7ghcNuO8d/c2fOP8lntb8W9ZB nicolas@archlinux" ];
  services.openssh.settings.PermitRootLogin = "yes";

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  system.stateVersion = "24.05"; # Did you read the comment?
  fileSystems."/mnt/video" = {
    device = "192.168.1.10:/volume1/video";
    fsType = "nfs";
    options = [
      "_netdev"
    ];
  };
 
  fileSystems."/mnt/music" = {
    device = "192.168.1.10:/volume1/music";
    fsType = "nfs";
  };
  
  virtualisation.oci-containers = {
    containers = {
      jellyfin = {
        image = "jellyfin/jellyfin";
        volumes = [
          "/mnt/video:/video"
          "/mnt/music:/music"
          "/root/jellyfin/config:/config"
        ];
        extraOptions = [
          "--device=/dev/dri:/dev/dri"
          "-l=traefik.enable=true"
          "-l=traefik.http.routers.jellyfin.rule=Host(`jellyfin.${domainName}`)"
          "-l=traefik.http.services.jellyfin.loadbalancer.server.port=8096"
          "-l=homepage.group=Media"
          "-l=homepage.name=Jellyfin"
          "-l=homepage.href=https://jellyfin.${domainName}"
          "-l=homepage.description=Media player"
          "-l=homepage.widget.type=jellyfin"
          "-l=homepage.widget.key={{HOMEPAGE_FILE_JELLYFIN_KEY}}"
          "-l=homepage.widget.url=http://jellyfin:8096"
          "-l=homepage.widget.enableBlocks=true"
        ];
        environment = {
          TZ = "${timeZone}";
        };
      };

      traefik = {
        image = "traefik";
          cmd = [
            "--api.insecure=true"
            "--providers.docker=true"
            "--providers.docker.exposedbydefault=false"
            "--entrypoints.web.address=:80"
            "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
            "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"
            "--certificatesresolvers.letsencrypt.acme.email=${email.toAddress}"
            # HTTP
            "--entrypoints.web.address=:80"
            "--entrypoints.web.http.redirections.entrypoint.to=websecure"
            "--entrypoints.web.http.redirections.entrypoint.scheme=https"
            "--entrypoints.websecure.address=:443"
            # HTTPS
            "--entrypoints.websecure.http.tls=true"
            "--entrypoints.websecure.http.tls.certResolver=letsencrypt"
            "--entrypoints.websecure.http.tls.domains[0].main=${domainName}"
            "--entrypoints.websecure.http.tls.domains[0].sans=*.${domainName}"
          ];
          extraOptions = [
            # Proxying Traefik itself
            "-l=traefik.enable=true"
            "-l=traefik.http.routers.traefik.rule=Host(`proxy.${domainName}`)"
            "-l=traefik.http.services.traefik.loadbalancer.server.port=8080"
            "-l=homepage.group=Services"
            "-l=homepage.name=Traefik"
            "-l=homepage.icon=traefik.svg"
            "-l=homepage.href=https://proxy.${domainName}"
            "-l=homepage.description=Reverse proxy"
            "-l=homepage.widget.type=traefik"
            "-l=homepage.widget.url=http://traefik:8080"
          ];
        ports = [
          "443:443"
          "80:80"
        ];
        volumes = [
          "/var/run/podman/podman.sock:/var/run/docker.sock:ro"
          "${serviceConfigRoot}/traefik/acme.json:/acme.json"
        ];
      };
  };
  };
}
