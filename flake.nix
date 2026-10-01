{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    zmk-nix = {
      url = "github:lilyinstarlight/zmk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      zmk-nix,
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs (lib.attrNames zmk-nix.packages);
    in
    {
      packages = forAllSystems (
        system:
        let
          # Set this temporarily when GitHub rejects anonymous West fetches.
          githubToken = "";

          zephyrDepsHash = "sha256-39rJp9v09MGlZrNS2yIMHAUkE4asI/O3aU9ho2klq+E=";

          firmwareSrc = lib.sourceFilesBySuffices self [
            ".board"
            ".cmake"
            ".conf"
            ".defconfig"
            ".dts"
            ".dtsi"
            ".json"
            ".keymap"
            ".overlay"
            ".shield"
            ".yml"
            "_defconfig"
          ];

          firmwareWestDeps = zmk-nix.legacyPackages.${system}.fetchZephyrDeps {
            name = "firmware-west-deps";
            src = firmwareSrc;
            westRoot = "config";
            hash = zephyrDepsHash;
            preBuild = lib.optionalString (githubToken != "") ''
              export GIT_CONFIG_GLOBAL="$TMPDIR/github-token.gitconfig"
              git config --global http.https://github.com/.extraheader \
                "AUTHORIZATION: basic $(printf 'x-access-token:%s' ${lib.escapeShellArg githubToken} | base64 | tr -d '\n')"
            '';
          };
        in
        rec {
          default = firmware;

          firmware = zmk-nix.legacyPackages.${system}.buildSplitKeyboard {
            name = "firmware";

            src = firmwareSrc;
            westDeps = firmwareWestDeps;

            # Find the new board and zephyrDepsHash on:
            #  https://github.com/lilyinstarlight/zmk-nix/blob/main/nix/firmware.nix
            board = "nice_nano@2.0.0//zmk";
            shield = "cosmos_%PART%";
            inherit zephyrDepsHash;

            meta = {
              description = "ZMK firmware";
              license = nixpkgs.lib.licenses.mit;
              platforms = nixpkgs.lib.platforms.all;
            };

            enableZmkStudio = true;
          };

          flash = zmk-nix.packages.${system}.flash.override { inherit firmware; };
          update = zmk-nix.packages.${system}.update;
        }
      );

      devShells = forAllSystems (system: {
        default = zmk-nix.devShells.${system}.default;
      });
    };
}
