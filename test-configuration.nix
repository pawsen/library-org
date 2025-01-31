{ config, pkgs, ... }:

{
  imports = [
    ./flask-module.nix  # Import the Flask app module
  ];

  # Enable the Flask app
  services.flaskApp.enable = true;
  # Set the package to the one built by the flake
  services.flaskApp.package = (import ./flake.nix).packages.${pkgs.system}.default;

  # Optionally, set the domain (if your module supports it)
  services.flaskApp.domain = "bibliotek.dbkk.dk";

  # Enable networking (required for Nginx and Let's Encrypt)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.enable = false;

  # Optionally, disable Let's Encrypt for local testing
  # security.acme.acceptTerms = false;  # Disable Let's Encrypt for local testing
  # services.nginx.virtualHosts."bibliotek.dbkk.dk".enableACME = false;
  # services.nginx.virtualHosts."bibliotek.dbkk.dk".forceSSL = false;

  # Add a local DNS entry for testing
  networking.extraHosts = ''
    127.0.0.1 bibliotek.dbkk.dk
  '';

# services.xserver.enable = true;

    # Forward the hosts's port 2222 to the guest's SSH port.
    # Also, forward the MQTT port 1883 1:1 from host to guest.
    # virtualisation.forwardPorts = [
    #   { from = "host"; host.port = 2222; guest.port = 22; }
    #   { from = "host"; host.port = 1883; guest.port = 1883; }
    # ];

users.users.test.isSystemUser = true ;
users.users.test.initialPassword = "test";
users.users.test.group = "test";
users.groups.test = {};

    # Root user without password and enabled SSH for playing around
    # networking.firewall.enable = false;
    services.openssh.enable = true;
    services.openssh.permitRootLogin = "yes";
    users.extraUsers.root.password = "";
}

 # nixos-rebuild build-vm -I nixos-config=./test-configuration.nix
 # ./result/bin/run-nixos-vm
 # ssh -o StrictHostKeyChecking=no -p 2222 root@localhost

  # QEMU_NET_OPTS=“hostfwd=tcp::2222-:22” ./result/bin/run-*-vm

# Add the following lines to the beginning of /etc/ssh/ssh_config...

# Host localhost
#    StrictHostKeyChecking no
#    UserKnownHostsFile=/dev/null
