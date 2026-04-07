{
  description = "Elven Council - MTG voting app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beamPackages = pkgs.beamPackages;

        mixFodDeps = beamPackages.fetchMixDeps {
          pname = "elven-council-deps";
          version = "0.1.0";
          src = ./.;
          hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };
      in
      {
        packages.default = beamPackages.mixRelease {
          pname = "elven-council";
          version = "0.1.0";
          src = ./.;
          inherit mixFodDeps;

          nativeBuildInputs = [ pkgs.esbuild pkgs.tailwindcss_4 ];

          preBuild = ''
            # Use system-provided esbuild and tailwind binaries
            substituteInPlace config/config.exs \
              --replace-quiet 'version: "0.25.4"' 'path: System.get_env("ESBUILD_PATH", "${pkgs.esbuild}/bin/esbuild")' \
              --replace-quiet 'version: "4.1.12"' 'path: System.get_env("TAILWIND_PATH", "${pkgs.tailwindcss_4}/bin/tailwindcss")'
          '';

          postBuild = ''
            mix assets.deploy --no-deps-check
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            elixir
            erlang
            inotify-tools
          ];

          shellHook = ''
            export MIX_HOME="$PWD/.nix-mix"
            export HEX_HOME="$PWD/.nix-hex"
            export PATH="$MIX_HOME/bin:$MIX_HOME/escripts:$HEX_HOME/bin:$PATH"
            export ERL_AFLAGS="-kernel shell_history enabled"

            mix local.hex --if-missing --force > /dev/null 2>&1
            mix local.rebar --if-missing --force > /dev/null 2>&1
          '';
        };
      });
}
