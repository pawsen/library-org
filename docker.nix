
### XXX: DOES NOT WORK!!!

{
  description = "A flake for the Library Org Flask project with requirements.txt support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    mach-nix.url = "github:DavHau/mach-nix";
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonPackages = pkgs.python3Packages;
        machNix = mach-nix.lib.${system};

        # Create a Python environment using mach-nix
        pythonEnv = machNix.mkPython {
          requirements = builtins.readFile ./requirements.txt;
        };

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          name = "library-dev";
          venvDir = "./.venv";
          buildInputs = [
            pythonPackages.python
            pythonPackages.venvShellHook
          ];

          postVenvCreation = ''
            unset SOURCE_DATE_EPOCH
            pip install -r requirements.txt
          '';

          postShellHook = ''
            unset SOURCE_DATE_EPOCH
            echo ""
            echo "Environment is ready! Run this to start the app."
            echo "python3 src/controller.py"
            echo ""
          '';
        };

        # Docker image
        packages.dockerImage = pkgs.dockerTools.buildImage {
          name = "library";
          tag = "latest";

          # Copy the entire project into the Docker image (excluding uploads and database)
          copyToRoot = pkgs.buildEnv {
            name = "library-root";
            paths = [
              pkgs.bashInteractive
              pkgs.coreutils
              pythonEnv
              (pkgs.writeTextDir "requirements.txt"
                (builtins.readFile ./requirements.txt))
              (pkgs.copyPathToStore ./src)
              # (pkgs.copyPathToStore ./library.cfg)
            ];
          };

          # Install dependencies and organize files into /app
          # runAsRoot = ''
          #   # Create a working directory
          #   mkdir -p /app
          #   cp -r ${self}/src /app/src
          #   chown -R nobody:nogroup /app

          #   # Install Python dependencies
          #   # pip install -r /app/requirements.txt
          # '';

          # Docker configuration
          config = {
            Cmd =  [ "python" "-m" "flask" "run" "--host=0.0.0.0" ];
            # Cmd = [ "flask" "run" "--host=0.0.0.0" ];
            WorkingDir = "/app";
            Env = [ "FLASK_APP=src/controller.py" "FLASK_ENV=production"  # "PYTHONPATH=/app/src/:$PYTHONPATH"
                    # A user is required by nix
                    # https://github.com/NixOS/nix/blob/9348f9291e5d9e4ba3c4347ea1b235640f54fd79/src/libutil/util.cc#L478
                  "USER=nobody"
                  ];
            ExposedPorts = { "5000/tcp" = { }; };
            # User = "nobody";
            Volumes = {
              "/app/uploads" = { };
              "/app/database" = { };
              "/app/library.cfg" = { };
            };
          };
        };
      });
}
