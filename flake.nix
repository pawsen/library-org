{
  description =
    "A flake for the Library Org Flask project with requirements.txt support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonPackages = pkgs.python3Packages;
      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          name = "library-org-dev";
          venvDir = "./.venv";
          buildInputs = [ pythonPackages.python pythonPackages.venvShellHook ];

          postVenvCreation = ''
            unset SOURCE_DATE_EPOCH
            pip install -r requirements.txt
          '';

          postShellHook = ''
            unset SOURCE_DATE_EPOCH
            echo ""
            echo "Environment is ready! Run the command below to start the app."
            echo "set -x FLASK_APP src/controller.py; set -x FLASK_DEBUG 1; python3 -m flask run --host 0.0.0.0"
            echo ""
          '';
        };

        # Docker image
        packages.dockerImage = pkgs.dockerTools.buildImage {
          name = "library-org";
          tag = "latest";

          # Copy the entire project into the Docker image
          copyToRoot = pkgs.buildEnv {
            name = "library-org-root";
            paths = [
              (pkgs.python3.withPackages (ps:
                with ps; [
                  flask
                  flask-sqlalchemy
                  flask-wtf
                  requests
                  # Add other dependencies from requirements.txt here
                ]))
              (pkgs.writeTextDir "requirements.txt"
                (builtins.readFile ./requirements.txt))
              (pkgs.copyPathToStore ./.)
            ];
          };

          # Install dependencies using pip
          runAsRoot = ''
            # Create a working directory
            mkdir -p /app
            cp -r ${self}/* /app
            chown -R nobody:nogroup /app
          '';

          # Docker configuration
          config = {
            Cmd = [ "flask" "run" "--host=0.0.0.0" ];
            WorkingDir = "/app";
            Env = [ "FLASK_APP=src/controller.py" "FLASK_ENV=production" ];
            ExposedPorts = { "5000/tcp" = { }; };
            User = "nobody";
          };
        };
      });
}
