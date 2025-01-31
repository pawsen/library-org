{
  description = "A flake for the Library Org Flask project with requirements.txt support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, mach-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pythonPackages = pkgs.python3Packages;

        # Define the Flask app package
        flaskAppPackage = pythonPackages.buildPythonApplication {
          pname = "library-org";
          version = "0.1.0";
          src = ./.;

          propagatedBuildInputs = with pythonPackages; [
            flask
            flask-sqlalchemy
            flask-wtf
            requests
            gunicorn
          ];

          # Install the app as a Python package
          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/lib/${pythonPackages.python.libPrefix}/site-packages/library-org
            cp -r . $out/lib/${pythonPackages.python.libPrefix}/site-packages/library-org
            echo "#!/bin/sh" > $out/bin/library-org
            echo "export PYTHONPATH=$out/lib/${pythonPackages.python.libPrefix}/site-packages" >> $out/bin/library-org
            echo "gunicorn --bind 127.0.0.1:5000 wsgi:app" >> $out/bin/library-org
            chmod +x $out/bin/library-org
          '';
        };
      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          name = "library-dev";
          venvDir = "./.venv";
          buildInputs = [
            pythonPackages.python
            # these are already in the requirements.txt
            # pythonPackages.gunicorn
            # pythonPackages.flask
            pythonPackages.venvShellHook
          ];

          postVenvCreation = ''
            unset SOURCE_DATE_EPOCH
            pip install -r requirements.txt
          '';

          postShellHook = ''
            unset SOURCE_DATE_EPOCH
            echo ""
            echo "Environment is ready! Run either to start the app."
            echo "python3 src/controller.py"
            echo "gunicorn --bind 127.0.0.1:5000 wsgi:app"
            echo ""
          '';
        };

        # Expose the Flask app package
        packages.default = flaskAppPackage;
      });
}
