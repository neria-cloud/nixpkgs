# The package set for this flake. Each attribute here becomes
# packages.<system>.<name> (and an overlay attribute). Add a package by dropping
# a directory under pkgs/<name>/ with a default.nix, then wiring it below with
# `callPackage` (callPackage auto-fills derivation args from nixpkgs: stdenv,
# fetchurl, lib, autoPatchelfHook, ...).
{ pkgs }:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  inherit (pkgs) lib;
in
{
  # Trivial, dependency-free smoke test — proves the flake evaluates + builds on
  # any system (incl. macOS), with no network fetch:
  #   nix build .#hello-neria && ./result/bin/hello-neria
  hello-neria = pkgs.writeShellScriptBin "hello-neria" ''
    echo "hello from neria-cloud/nixpkgs on $(uname -sm)"
  '';
}
# Linux-only packages (the agent runtime). Wrappers around precompiled Linux
# binaries live here so `nix flake check` on a dev Mac doesn't try (and fail) to
# evaluate Linux-only assets.
// lib.optionalAttrs isLinux {
  # gogcli — script-friendly Google CLI (statically-linked Go release binary).
  # This is the reference pattern for wrapping a precompiled GitHub-release
  # binary; copy pkgs/gogcli/ as a starting point for new wrappers.
  gogcli = pkgs.callPackage ./gogcli { };

  # ocis-mcp-server — MCP server fronting ownCloud Infinite Scale (oCIS).
  # Statically-linked Go release binary, same wrapper pattern as gogcli.
  ocis-mcp-server = pkgs.callPackage ./ocis-mcp-server { };
}
