let
  pkgs = import <nixpkgs> { };

  # This module defines the system that we want
  mqttModule = { ... }: {
    # Enable mosquitto without any authentication for the beginning, as also
    # documented in the NixOS documentation:
    # https://nixos.org/manual/nixos/stable/index.html#module-services-mosquitto
    services.mosquitto = {
      enable = true;
      listeners = [ {
        acl = [ "pattern readwrite #" ];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      } ];
    };
  };

  # This module describes the part of the system that only makes sense in our
  # test VM scenario, like empty root password and port forward rules.
  debugVm = { modulesPath, ... }: {
    imports = [
      # The qemu-vm NixOS module gives us the `vm` attribute that we will later
      # use, and other VM-related settings
      "${modulesPath}/virtualisation/qemu-vm.nix"
    ];

    # Forward the hosts's port 2222 to the guest's SSH port.
    # Also, forward the MQTT port 1883 1:1 from host to guest.
    virtualisation.forwardPorts = [
      { from = "host"; host.port = 2222; guest.port = 22; }
      { from = "host"; host.port = 1883; guest.port = 1883; }
    ];

    # Root user without password and enabled SSH for playing around
    networking.firewall.enable = false;
    services.openssh.enable = true;
    services.openssh.permitRootLogin = "yes";
    users.extraUsers.root.password = "";
  };

  nixosEvaluation = pkgs.nixos [
    debugVm
    mqttModule
  ];
in

nixosEvaluation.config.system.build.vm


# nix-build another-vm.nix
# $(nix-build another-vm.nix)/bin/run-nixos-vm
