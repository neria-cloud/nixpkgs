# ocis-mcp-server — a Model Context Protocol server exposing ownCloud Infinite
# Scale (oCIS) as ~80 AI-callable tools.
# https://github.com/owncloud/ocis-mcp-server
#
# Same shape as pkgs/gogcli: upstream ships *statically-linked* (CGO-free) Go
# release binaries, verified with `file`:
#   ELF 64-bit LSB executable, x86-64 … statically linked, Go BuildID=… stripped
#   ELF 64-bit LSB executable, ARM aarch64 … statically linked, Go BuildID=… stripped
# A static ELF has no dynamic interpreter and no DT_NEEDED entries, so there is
# nothing for autoPatchelfHook to rewrite and no buildInputs to declare — and
# nothing to compile, hence stdenvNoCC rather than a full C toolchain.
#
# Configuration is env-vars ONLY — the binary parses no flags at all (`--help`
# and `--version` both exit 1 with `OCIS_MCP_OCIS_URL is required`). The ones
# that matter to a supervised service:
#   OCIS_MCP_OCIS_URL        required — base URL of the oCIS instance
#   OCIS_MCP_TRANSPORT       stdio (default) | http
#   OCIS_MCP_HTTP_ADDR       listen address for the http transport (default 127.0.0.1:8090)
#   OCIS_MCP_HTTP_SECRET     bearer secret for /mcp; REQUIRED for a non-loopback bind
#   OCIS_MCP_APP_TOKEN_USER / OCIS_MCP_APP_TOKEN_VALUE   app-token auth (recommended)
#   OCIS_MCP_LOG_LEVEL       debug | info | warn | error
#
# Updating: bump `version`, set each `hash` to lib.fakeHash, run
#   nix build path:.#packages.aarch64-linux.ocis-mcp-server
# and paste back the sha256-… Nix prints. Or prefetch directly:
#   nix store prefetch-file --json <asset-url> | jq -r .hash
# Upstream also publishes checksums.txt next to the assets; the hashes below
# were cross-checked against it.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "1.1.0";

  # Release assets are named by Go's GOARCH (amd64/arm64), not Nix's system
  # tuples (x86_64/aarch64) — map them explicitly. Only Linux is packaged: the
  # agent runtime is Linux, and darwin/windows assets exist upstream but are
  # deliberately not wired up here.
  assets = {
    "x86_64-linux" = {
      goarch = "amd64";
      hash = "sha256-l3jGRZH6jy0+bzO0/D/0/4aIqw1IM5kqAs67AMlw01s=";
    };
    "aarch64-linux" = {
      goarch = "arm64";
      hash = "sha256-MaPdQAB3mbDOsdVLl5hiWBlMbQkbrLUGizBGIriGvKA=";
    };
  };
  asset =
    assets.${stdenvNoCC.hostPlatform.system}
      or (throw "ocis-mcp-server: no prebuilt release asset for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "ocis-mcp-server";
  inherit version;

  src = fetchurl {
    url = "https://github.com/owncloud/ocis-mcp-server/releases/download/v${version}/ocis-mcp-server_${version}_linux_${asset.goarch}.tar.gz";
    inherit (asset) hash;
  };

  # The tarball extracts ocis-mcp-server + CHANGELOG.md + LICENSE + README.md +
  # LICENSES/ at the top level (no wrapping directory), so unpack in place
  # rather than into a subdir.
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  # Static binary: no dynamic interpreter or RPATH to rewrite, so skip
  # fixupPhase's patchelf step (it would otherwise just warn "cannot find
  # section '.dynamic'" and no-op).
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ocis-mcp-server $out/bin/ocis-mcp-server
    install -Dm644 LICENSE $out/share/doc/ocis-mcp-server/LICENSE
    install -Dm644 README.md $out/share/doc/ocis-mcp-server/README.md
    install -Dm644 CHANGELOG.md $out/share/doc/ocis-mcp-server/CHANGELOG.md
    runHook postInstall
  '';

  meta = {
    description = "Model Context Protocol server exposing ownCloud Infinite Scale users, groups, spaces, files and shares as AI-callable tools";
    homepage = "https://github.com/owncloud/ocis-mcp-server";
    changelog = "https://github.com/owncloud/ocis-mcp-server/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "ocis-mcp-server";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    # Prebuilt upstream binary, not built from source by Nix.
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
