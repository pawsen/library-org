{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils = {
      url = github:numtide/flake-utils;
    };
    mach-nix.url = "mach-nix/3.5.0";
  };

  outputs = {self, nixpkgs, flake-utils, mach-nix, ... }@inp:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        machNix = mach-nix.lib."${system}";
        l = nixpkgs.lib // builtins;

        pyEnv = machNix.mkPython {
          requirements = builtins.readFile ./requirements_machnix.txt;
        };

      in
        {
          devShell = pkgs.mkShell {
            buildInputs = with pkgs; [
              pyEnv
            ];
            shellHook = ''
            export FLASK_DEBUG=1 FLASK_APP=src/controller.py
            echo "python -m flask run"
          '';
          };

          # enter this python environment by executing `nix shell .`
          defaultPackage = pyEnv;

        });
}
