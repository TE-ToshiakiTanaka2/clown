#!/bin/bash
# =============================================================================
# setup-godot.sh — Install Godot 4 (headless-capable) and godot-mcp (#1)
# =============================================================================
# Installs a pinned Godot 4 Linux x86_64 editor binary to /usr/local/bin/godot
# and clones+builds Coding-Solo/godot-mcp (pinned to a known-good commit) so
# Claude Code / Codex CLI can drive Godot headlessly via MCP. Idempotent: safe
# to re-run; skips work that is already done at the pinned versions.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Pinned versions
# -----------------------------------------------------------------------------
# Latest stable release per https://github.com/godotengine/godot/releases
# at the time this script was authored (2026-07-12).
readonly GODOT_VERSION="4.7"
readonly GODOT_ZIP="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
readonly GODOT_DOWNLOAD_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${GODOT_ZIP}"
readonly GODOT_BIN_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64"
readonly GODOT_INSTALL_PATH="/usr/local/bin/godot"

# Pinned to a specific upstream commit (main branch, 2026-07-12) so the MCP
# server build is reproducible: fix: prevent arbitrary GDScript instantiation
# via add_node/create_scene (PR #99).
readonly GODOT_MCP_REPO="https://github.com/Coding-Solo/godot-mcp.git"
readonly GODOT_MCP_COMMIT="1209744fad78f3998f98c7394fd0f6ef50da5281"
readonly GODOT_MCP_DIR="${HOME}/tools/godot-mcp"

print_info()    { echo "[INFO] $*"; }
print_success() { echo "[OK] $*"; }
print_warning() { echo "[WARN] $*" >&2; }
print_error()   { echo "[ERROR] $*" >&2; }

# -----------------------------------------------------------------------------
# ensure_apt_deps — install packages Godot/MCP setup needs, if missing.
# -----------------------------------------------------------------------------
ensure_apt_deps() {
    local -a missing=()

    command -v unzip &>/dev/null || missing+=("unzip")
    command -v curl &>/dev/null || missing+=("curl")

    # Godot's editor binary links against libfontconfig, libxcursor/xrandr/
    # xinerama/xi (X11 input/display extensions), libgl1/libglx (GL loader),
    # and libasound2/libpulse (audio). Even headless runs (`--headless`)
    # dlopen a subset of these; missing libs surface as ELF loader errors.
    local -a runtime_pkgs=(
        libfontconfig1
        libxcursor1
        libxinerama1
        libxrandr2
        libxi6
        libgl1
        libglu1-mesa
        libasound2t64
        libpulse0
        libdbus-1-3
    )
    local pkg
    for pkg in "${runtime_pkgs[@]}"; do
        dpkg -s "$pkg" &>/dev/null || missing+=("$pkg")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_success "setup-godot: all apt dependencies already present"
        return 0
    fi

    print_info "setup-godot: installing missing apt packages: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "${missing[@]}"
    sudo rm -rf /var/lib/apt/lists/*
}

# -----------------------------------------------------------------------------
# install_godot — download + install the pinned Godot binary, idempotently.
# -----------------------------------------------------------------------------
install_godot() {
    if [[ -x "$GODOT_INSTALL_PATH" ]]; then
        local installed_version
        installed_version=$("$GODOT_INSTALL_PATH" --headless --version 2>/dev/null || echo "")
        if [[ "$installed_version" == *"${GODOT_VERSION}."*stable* ]] \
            || [[ "$installed_version" == "${GODOT_VERSION}-stable"* ]]; then
            print_success "setup-godot: Godot ${GODOT_VERSION} already installed at ${GODOT_INSTALL_PATH}"
            return 0
        fi
        print_info "setup-godot: existing godot binary is a different version (${installed_version}); reinstalling"
    fi

    local work_dir
    work_dir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${work_dir}'" RETURN

    print_info "setup-godot: downloading ${GODOT_DOWNLOAD_URL}"
    curl -fsSL --retry 3 -o "${work_dir}/${GODOT_ZIP}" "$GODOT_DOWNLOAD_URL"

    print_info "setup-godot: unzipping ${GODOT_ZIP}"
    unzip -q -o "${work_dir}/${GODOT_ZIP}" -d "$work_dir"

    if [[ ! -f "${work_dir}/${GODOT_BIN_NAME}" ]]; then
        print_error "setup-godot: expected binary ${GODOT_BIN_NAME} not found after unzip"
        return 1
    fi

    chmod +x "${work_dir}/${GODOT_BIN_NAME}"
    sudo install -m 0755 "${work_dir}/${GODOT_BIN_NAME}" "$GODOT_INSTALL_PATH"

    print_success "setup-godot: installed Godot ${GODOT_VERSION} to ${GODOT_INSTALL_PATH}"
}

# -----------------------------------------------------------------------------
# install_godot_mcp — clone (pinned commit) + build godot-mcp, idempotently.
# -----------------------------------------------------------------------------
install_godot_mcp() {
    if [[ ! -d "$GODOT_MCP_DIR" ]]; then
        print_info "setup-godot: cloning godot-mcp into ${GODOT_MCP_DIR}"
        mkdir -p "$(dirname "$GODOT_MCP_DIR")"
        git clone --quiet "$GODOT_MCP_REPO" "$GODOT_MCP_DIR"
        git -C "$GODOT_MCP_DIR" checkout --quiet "$GODOT_MCP_COMMIT"
    else
        print_info "setup-godot: ${GODOT_MCP_DIR} already exists; skipping clone"
    fi

    if [[ ! -f "${GODOT_MCP_DIR}/build/index.js" ]]; then
        print_info "setup-godot: building godot-mcp (npm install && npm run build)"
        (cd "$GODOT_MCP_DIR" && npm install --no-audit --no-fund && npm run build)
        print_success "setup-godot: godot-mcp built at ${GODOT_MCP_DIR}/build/index.js"
    else
        print_success "setup-godot: godot-mcp already built at ${GODOT_MCP_DIR}/build/index.js"
    fi
}

main() {
    print_info "setup-godot: starting (Godot ${GODOT_VERSION}, godot-mcp @ ${GODOT_MCP_COMMIT:0:7})"
    ensure_apt_deps
    install_godot
    install_godot_mcp
    print_success "setup-godot: done"
}

main "$@"
