{
  description = "neria-cloud custom Nix packages: first-party tools + wrappers for binaries released on other GitHub repos. The agent images install from here via the pinned flakeref github:neria-cloud/nixpkgs/<rev>#<pkg>.";

  inputs = {
    # Pin nixpkgs to the SAME release the agent images use (images-b2
    # skills.yml `nix.channel`) so stdenv / glibc / autoPatchelfHook line up with
    # the agent runtime. Bump both together. `nix flake update` writes flake.lock.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Agent runtime arches first; darwin is included so the dependency-free
      # smoke-test package builds on a dev Mac without a Linux builder.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      inherit (nixpkgs) lib;
      forAllSystems = f: lib.genAttrs systems (system: f system);
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # packages.<system>.<name> — exactly what
      #   nix profile install github:neria-cloud/nixpkgs/<rev>#<name>
      # resolves to. The set is defined once in ./pkgs.
      packages = forAllSystems (system: import ./pkgs { pkgs = pkgsFor system; });

      # The same package set as a nixpkgs overlay, for consumers who compose via
      # overlays rather than flakerefs.
      overlays.default = final: _prev: import ./pkgs { pkgs = final; };

      # `nix fmt` formats this repo.
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);
    };
}
