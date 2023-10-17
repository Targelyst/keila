{
  description = "Open Source Newsletter Tool.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beam = pkgs.beam.packagesWith pkgs.beam.interpreters.erlang_25;
      in
      {
        packages = rec {
          keila = beam.mixRelease {
            mixNixDeps = with pkgs; import ./mix.nix {
              inherit lib beamPackages;
            };

            src = self;
            pname = "keila";
            version = "0.12.6";
          };

          default = keila;
        };

        devShells.default =
          let
            initDbScript = pkgs.writeShellScriptBin "initDevDB" ''
              initdb -D "$PGDATA"
              pg_ctl -D "$PGDATA" -l "$PGDATA/server.log" -o "--unix_socket_directories='$PWD'" start
              createdb keila_dev
              createuser postgres -ds
              pg_ctl -D "$PGDATA" stop
            '';

            startDbScript = pkgs.writeShellScriptBin "startDevDB" ''
              pg_ctl -D "$PGDATA" -l "$PGDATA/server.log" -o "--unix_socket_directories='$PWD'" start
            '';

            stopDbScript = pkgs.writeShellScriptBin "stopDevDB" ''
              pg_ctl -D "$PGDATA" stop
            '';

            initScript = pkgs.writeShellScriptBin "initKeilaDev" ''
              initDevDB

              startDevDB
              mix setup
              stopDevDB
            '';
          in
          pkgs.mkShell {
            buildInputs = with pkgs; [
              elixir_1_14
              mix2nix

              nodejs
              nodePackages.node2nix

              postgresql
              initDbScript
              startDbScript
              stopDbScript

              initScript
            ];

            shellHook = ''
              mkdir -p .nix-mix .nix-hex

              export MIX_HOME=$PWD/.nix-mix
              export HEX_HOME=$PWD/.nix-mix
              export MIX_PATH="${pkgs.beam.packages.erlang.hex}/lib/erlang/lib/hex/ebin"
              export MIX_REBAR3="${pkgs.rebar3}/bin/rebar3"
              export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
              export LANG=C.UTF-8
              export ERL_AFLAGS="-kernel shell_history enabled"

              export PGDATA="$PWD/.db"
              export PGHOST="$PWD"
              export POOL_SIZE=15
              export DB_URL="postgresql://postgres:postgres@localhost:5432/keila_dev"

              export PORT=4000
              export MIX_ENV=dev

              export KEILA_USER=admin
              export KEILA_PASSWORD=admin
            '';
          };
      });
}
