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
      });
}
