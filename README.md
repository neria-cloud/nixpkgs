# neria-cloud/nixpkgs

A small **Nix flake** holding Neria's own packages: first-party tools and thin
wrappers around precompiled binaries released on *other* GitHub repos. The agent
images install from here with a pinned flakeref, so every agent gets the exact
same package at the exact same revision.

```
nix profile install github:neria-cloud/nixpkgs/<rev>#<pkg>
```

## Layout

```
flake.nix                     inputs (nixpkgs) + outputs (packages.<system>.*, overlays.default)
flake.lock                    pins nixpkgs to an exact commit  (run `nix flake update`)
pkgs/
  default.nix                 the package set: { pkgs }: { <name> = …; }  — add packages here
  gogcli/default.nix          example: wrap a GitHub-release binary as a Nix package
```

`pkgs/default.nix` is a plain `{ pkgs }:` function returning an attrset of
packages. `flake.nix` evaluates it once per system and exposes it both as
`packages.<system>.<name>` and as `overlays.default`.

Supported systems: `x86_64-linux` + `aarch64-linux` (the agent runtime), plus
darwin for the dependency-free smoke test so the flake builds on a dev Mac.

## Add a package

1. `cp -r pkgs/gogcli pkgs/<your-tool>` and edit its `default.nix`
   (owner/repo, version, the per-arch asset name, and the hashes).
2. Wire it in `pkgs/default.nix`:
   ```nix
   <your-tool> = pkgs.callPackage ./<your-tool> { };
   ```
3. Get the hashes: leave them as `lib.fakeHash`, run `nix build .#<your-tool>`,
   and paste the `sha256-…` Nix prints in the mismatch error. Or:
   ```sh
   nix store prefetch-file --json <release-asset-url> | jq -r .hash
   ```

The wrapper pattern (see `pkgs/gogcli/default.nix`): `fetchurl` the hashed
release asset, then install to `$out/bin`. gogcli's upstream binary is
statically linked, so it needs nothing more (and uses `stdenvNoCC`). For a
*dynamically*-linked ELF, add `autoPatchelfHook` to `nativeBuildInputs` to fix
the interpreter/RPATH and list the binary's shared libs in `buildInputs`.

## Build / test locally

```sh
nix build .#hello-neria && ./result/bin/hello-neria   # smoke test (any OS)
nix build .#<pkg>                                     # build one package (Linux)
nix flake check                                       # evaluate every output
nix fmt                                               # format the .nix files
nix flake update                                      # refresh flake.lock (commit it)
```

Building Linux packages on macOS needs a Linux builder (a remote builder, or
`nix` inside Docker / a NixOS VM). The smoke test builds natively anywhere.

## How the agent images consume this

`nixpkgs`'s `inputs.nixpkgs.url` is pinned to the **same** release the images use
(`images-b2/skills.yml` `nix.channel` → `nixos-26.05`); keep them in sync so
`glibc`/`stdenv`/`autoPatchelfHook` match the agent runtime.

The images repo bakes a manifest of `{flakeURL, rev, packages}` and the launcher
installs each package with a fully-pinned flakeref
(`github:neria-cloud/nixpkgs/<rev>#<pkg>`), reproducible across all agents. Wiring
the images `skills.yml` schema + resolver + installer to reference this flake (in
addition to nixpkgs) is the open work tracked in
`images-b2` (the `custom/third-party nix repositories per skill` TODO).

## Notes

- **Private repo / auth.** If this repo is private, the agent's Nix needs a
  credential at install time — a GitHub token in `/etc/nix/nix.conf`
  (`access-tokens = github.com=…`), a git `netrc`, or an SSH key — provisioned
  alongside the other agent secrets, not baked into the image.
- **Binary cache.** Custom packages are not on `cache.nixos.org`, so Nix *builds*
  the wrapper derivation on first install (download + patchelf — seconds). To
  skip even that across agents, run your own binary cache and add it as a
  substituter.
- **Reproducibility.** Asset hashes + the pinned nixpkgs rev (`flake.lock`) make
  every build content-addressed; commit `flake.lock`.
