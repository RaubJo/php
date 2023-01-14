{
  description = "PHP/Composer/SymfonyCLi/GithubCLi/git/sqlite/make";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-phps.url = "github:fossar/nix-phps";
  };

  outputs = inputs: let
    phps = import ./src/phps.nix inputs.nixpkgs inputs.nix-phps;

    api = phps;
  in
    {
      inherit api;
    }
    // inputs.flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = import ./src/pkgs.nix inputs.nixpkgs inputs.nix-phps system;

        makePhp = phps.makePhp system;
        makePhpEnv = phps.makePhpEnv system;

        errorMsg = ''
          ********************************************************************
          Since the 14th of November 2022, PHP is built by default
          in NTS mode (see https://github.com/NixOS/nixpkgs/pull/194172).
          Therefore, the '-nts' suffix is obsolete and can be now removed from
          your command line or from your '.envrc' file.
          ********************************************************************
        '';

        packages =
          builtins.mapAttrs
          (
            name: phpConfig:
              pkgs.buildEnv
              {
                inherit name;

                paths = [
                  (makePhp phpConfig)
                ];
              }
          )
          phps.matrix
          // inputs.nixpkgs.lib.mapAttrs'
          (
            name: phpConfig: let
              pname = "env-" + name;
            in
              pkgs.lib.nameValuePair
              pname
              (
                makePhpEnv pname (makePhp phpConfig)
              )
          )
          phps.matrix;

        devShells =
          (builtins.mapAttrs
            (
              name: phpConfig:
                pkgs.mkShellNoCC {
                  inherit name;

                  buildInputs = [
                    (makePhp phpConfig)
                  ];
                }
            )
            phps.matrix)
          // inputs.nixpkgs.lib.mapAttrs'
          (
            name: phpConfig: let
              pname = "env-" + name;
            in
              pkgs.lib.nameValuePair
              pname
              (
                pkgs.mkShellNoCC {
                  name = pname;

                  buildInputs = [
                    (makePhpEnv pname (makePhp phpConfig))
                  ];
                }
              )
          )
          phps.matrix;
      in {
        formatter = pkgs.alejandra;

        # In use for "nix shell"
        packages =
          packages
          // inputs.nixpkgs.lib.mapAttrs'
          (
            name: phpConfig:
              pkgs.lib.nameValuePair
              (name + "-nts")
              (throw errorMsg)
          )
          packages;

        # In use for "nix develop"
        devShells =
          devShells
          // inputs.nixpkgs.lib.mapAttrs'
          (
            name: phpConfig:
              pkgs.lib.nameValuePair
              (name + "-nts")
              (throw errorMsg)
          )
          devShells;
      }
    );
}
