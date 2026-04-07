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
      in
      {
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
