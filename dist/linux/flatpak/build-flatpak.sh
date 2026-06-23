#!/usr/bin/env bash
set -euo pipefail

# Build a Flatpak bundle for Reva Player from the local source tree and install
# it for the current user from a local OSTree repo.
#
# This mirrors the structure of scripts/build-appimage.sh (readonly project
# vars, usage/die helpers, option parsing). It does NOT source
# scripts/lib/bundle-runtime.sh because flatpak-builder performs its own
# sandboxed build against the org.kde.Sdk and does not bundle host runtime
# libraries the way the AppImage/DEB paths do.

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd)"
readonly APP_ID="io.github.moayad30.revaplayer"
readonly APP_DISPLAY_NAME="Reva Player"
readonly RUNTIME="org.kde.Platform"
readonly SDK="org.kde.Sdk"
readonly RUNTIME_VERSION="6.10"
readonly MANIFEST="${SCRIPT_DIR}/${APP_ID}.yaml"
readonly REMOTE_NAME="local-revaplayer"

build_dir="${PROJECT_ROOT}/build-flatpak"
repo_dir="${PROJECT_ROOT}/dist/flatpak/repo"
state_dir="${PROJECT_ROOT}/build-flatpak-state"
do_install="1"

usage() {
    cat <<EOF
Usage: scripts/build-flatpak.sh [options]

Build a Flatpak for ${APP_DISPLAY_NAME} (${APP_ID}) using flatpak-builder,
export it into a local OSTree repo, and install it for the current user.

Prerequisites (see docs/packaging/FLATPAK.md):
  - flatpak and flatpak-builder installed
  - flathub remote configured (for the org.kde.Platform/SDK 6.10 runtime)

Options:
  --build-dir DIR     flatpak-builder build directory (default: build-flatpak)
  --repo-dir DIR      local OSTree repo output (default: dist/flatpak/repo)
  --state-dir DIR     flatpak-builder state/cache (default: build-flatpak-state)
  --no-install        build and export the repo, but do not install the app
  --help              show this help

Environment overrides:
  FLATPAK_BUILDER     path to flatpak-builder (default: resolved from PATH)
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --build-dir)
            [ $# -ge 2 ] || die "--build-dir requires an argument"
            build_dir="$2"
            shift 2
            ;;
        --repo-dir)
            [ $# -ge 2 ] || die "--repo-dir requires an argument"
            repo_dir="$2"
            shift 2
            ;;
        --state-dir)
            [ $# -ge 2 ] || die "--state-dir requires an argument"
            state_dir="$2"
            shift 2
            ;;
        --no-install)
            do_install="0"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1 (try --help)"
            ;;
    esac
done

flatpak_builder="${FLATPAK_BUILDER:-flatpak-builder}"
command -v flatpak >/dev/null 2>&1 || die "flatpak not found; install flatpak and flatpak-builder (see docs/packaging/FLATPAK.md)"
command -v "${flatpak_builder}" >/dev/null 2>&1 || die "flatpak-builder not found; install flatpak-builder (see docs/packaging/FLATPAK.md)"

[ -f "${MANIFEST}" ] || die "manifest not found: ${MANIFEST}"
[ -f "${PROJECT_ROOT}/CMakeLists.txt" ] || die "project root not found (expected CMakeLists.txt at ${PROJECT_ROOT})"

ensure_runtime() {
    local runtime_id="$1"
    if flatpak info "${runtime_id}//${RUNTIME_VERSION}" >/dev/null 2>&1; then
        return 0
    fi
    printf 'installing runtime %s//%s ...\n' "${runtime_id}" "${RUNTIME_VERSION}"
    if flatpak remote-list 2>/dev/null | grep -qi '^flathub\b'; then
        flatpak install --assumeyes flathub "${runtime_id}//${RUNTIME_VERSION}" || \
            die "failed to install ${runtime_id}//${RUNTIME_VERSION}; install it manually first"
    else
        die "runtime ${runtime_id}//${RUNTIME_VERSION} is not installed and the flathub remote is not configured; add flathub and install the runtime, then re-run"
    fi
}

ensure_runtime "${RUNTIME}"
ensure_runtime "${SDK}"

mkdir -p "${build_dir}" "${repo_dir}" "${state_dir}"

printf 'building %s Flatpak from %s\n' "${APP_DISPLAY_NAME}" "${MANIFEST}"

# Run flatpak-builder from the manifest directory so the `type: dir` source
# path (../../..) resolves to the project root regardless of whether
# flatpak-builder resolves it relative to the manifest file or to the CWD.
(
    cd -- "${SCRIPT_DIR}"
    "${flatpak_builder}" \
        --force-clean \
        --repo="${repo_dir}" \
        --state-dir="${state_dir}" \
        "${build_dir}" \
        "${MANIFEST}"
)

if [ "${do_install}" = "1" ]; then
    printf 'adding local remote %s -> %s\n' "${REMOTE_NAME}" "${repo_dir}"
    flatpak remote-add --user --if-not-exists --no-gpg-verify "${REMOTE_NAME}" "${repo_dir}"

    printf 'installing %s for the current user ...\n' "${APP_ID}"
    flatpak install --user --assumeyes --reinstall "${REMOTE_NAME}" "${APP_ID}"
fi

printf '%s Flatpak ready.\n' "${APP_DISPLAY_NAME}"
printf '  app id : %s\n' "${APP_ID}"
printf '  repo   : %s\n' "${repo_dir}"
if [ "${do_install}" = "1" ]; then
    printf '  run    : flatpak run %s\n' "${APP_ID}"
else
    printf '  install: flatpak remote-add --user --no-gpg-verify %s %s && flatpak install --user %s %s\n' \
        "${REMOTE_NAME}" "${repo_dir}" "${REMOTE_NAME}" "${APP_ID}"
fi
