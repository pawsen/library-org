{ config, lib, pkgs, ... }:

let
  flaskAppDir = "/var/lib/flask-app";
  flaskAppSrc = "/home/paw/git/library-org";  # Path to your Flask app source
in {
  options.services.flaskApp = {
    enable = lib.mkEnableOption "Enable Flask App";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "bibliotek.dbkk.dk";
      description = "Domain for the Flask app";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage (import "${flaskAppSrc}/flake.nix") { };
      description = "Flask app package";
    };
  };

  config = lib.mkIf config.services.flaskApp.enable {
    # Enable Nginx
    services.nginx = {
      enable = true;
      virtualHosts.${config.services.flaskApp.domain} = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:5000";
          proxyWebsockets = true;
        };
      };
    };

    # Enable Let's Encrypt for HTTPS (optional for local testing)
    # security.acme.acceptTerms = true;
    # security.acme.defaults.email = "your-email@example.com";
    # services.nginx.virtualHosts.${config.services.flaskApp.domain}.enableACME = true;
    # services.nginx.virtualHosts.${config.services.flaskApp.domain}.forceSSL = true;

    # Install Python and Gunicorn
    environment.systemPackages = with pkgs; [
      python3
      python3Packages.gunicorn
    ];

    # Create a systemd service for the Flask app
    systemd.services.flask-app = {
      description = "Flask App";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/gunicorn --bind 127.0.0.1:5000 wsgi:app";
        WorkingDirectory = flaskAppDir;
        User = "flask";
        Group = "flask";
        Restart = "always";
      };

      preStart = ''
        mkdir -p ${flaskAppDir}
        cp -r ${config.services.flaskApp.package}/lib/${pkgs.python3.sitePackages}/library-org/* ${flaskAppDir}
        # cp -r ${config.services.flaskApp.package.src}/* ${flaskAppDir}
        # cp -r ${flaskAppSrc}/* ${flaskAppDir}
        chown -R flask:flask ${flaskAppDir}
      '';
    };

    # Create a user for the Flask app
    users.users.flask = {
      isSystemUser = true;
      group = "flask";
    };
    users.groups.flask = {};
  };
}
