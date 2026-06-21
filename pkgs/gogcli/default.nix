# gogcli — a script-friendly Google CLI (Gmail, Calendar, Drive, Docs, …).
# https://github.com/openclaw/gogcli
#
# Upstream ships *statically-linked* Go release binaries, so this is a plain
# fetch-and-install: no autoPatchelfHook and no buildInputs are needed (a static
# ELF has no dynamic interpreter or DT_NEEDED libraries to rewrite). That also
# lets us use stdenvNoCC — there is nothing to compile, so we don't pull a C
# toolchain into the build.
#
# Note the names differ: the project/repo/asset is `gogcli`, the binary is `gog`.
#
# Updating: bump `version`, set each `hash` to lib.fakeHash, run
#   nix build path:.#packages.x86_64-linux.gogcli
# and paste back the sha256-… Nix prints. Or prefetch directly:
#   nix store prefetch-file --json <asset-url> | jq -r .hash
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.29.0";

  # Release assets are named by Go's GOARCH (amd64/arm64), not Nix's system
  # tuples (x86_64/aarch64) — map them explicitly.
  assets = {
    "x86_64-linux" = {
      goarch = "amd64";
      hash = "sha256-IAGrjo4t+5eRavDfJbJzdj7Ca0njxCWWHmaJPKfQBp8=";
    };
    "aarch64-linux" = {
      goarch = "arm64";
      hash = "sha256-26w5OO1dVENUUxAdXGDOLRwscv7aO1P0t1o5W8UPCbk=";
    };
  };
  asset =
    assets.${stdenvNoCC.hostPlatform.system}
      or (throw "gogcli: no prebuilt release asset for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "gogcli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openclaw/gogcli/releases/download/v${version}/gogcli_${version}_linux_${asset.goarch}.tar.gz";
    inherit (asset) hash;
  };

  # The tarball extracts gog + LICENSE + README.md + CHANGELOG.md at the top
  # level (no wrapping directory), so unpack in place rather than into a subdir.
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Static binary: there is no dynamic interpreter or RPATH to rewrite, so skip
  # fixupPhase's patchelf step (it would otherwise just warn "cannot find
  # section '.dynamic'" and no-op).
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 gog $out/bin/gog
    install -Dm644 LICENSE $out/share/doc/gogcli/LICENSE
    install -Dm644 README.md $out/share/doc/gogcli/README.md
    install -Dm644 CHANGELOG.md $out/share/doc/gogcli/CHANGELOG.md
    runHook postInstall
  '';

  meta = {
    description = "Script-friendly Google CLI for Gmail, Calendar, Drive, Docs, Sheets, and more";
    homepage = "https://github.com/openclaw/gogcli";
    changelog = "https://github.com/openclaw/gogcli/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "gog";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    # Prebuilt upstream binary, not built from source by Nix.
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
