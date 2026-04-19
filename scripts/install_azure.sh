#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/install_azure.sh [OPTIONS]

Install Azure developer tooling.

Options:
  --cli-only           Install only Azure CLI.
  --with-azd           Also install Azure Developer CLI (azd).
  --with-bicep         Also install/update Bicep CLI via Azure CLI.
  -h, --help           Show this help message.
USAGE
}

log() {
  printf '\n[azure-install] %s\n' "$*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found." >&2
    exit 1
  fi
}

install_azure_cli_linux() {
  require_cmd curl

  if command -v apt-get >/dev/null 2>&1; then
    log "Installing Azure CLI on Debian/Ubuntu via Microsoft apt repo..."
    require_cmd gpg
    require_cmd sudo

    local codename
    codename="$(lsb_release -cs 2>/dev/null || echo '')"
    if [[ -z "$codename" ]]; then
      codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
    fi

    curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
      gpg --dearmor |
      sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg >/dev/null

    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ ${codename:-jammy} main" |
      sudo tee /etc/apt/sources.list.d/azure-cli.list

    sudo apt-get update -y
    sudo apt-get install -y azure-cli
    return
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Installing Azure CLI on Fedora/RHEL via dnf..."
    require_cmd sudo

    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    cat <<'REPO' | sudo tee /etc/yum.repos.d/azure-cli.repo >/dev/null
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
    sudo dnf install -y azure-cli
    return
  fi

  if command -v zypper >/dev/null 2>&1; then
    log "Installing Azure CLI on openSUSE/SLES via zypper..."
    require_cmd sudo

    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo zypper addrepo --gpgcheck --name 'azure-cli' \
      'https://packages.microsoft.com/yumrepos/azure-cli' azure-cli
    sudo zypper install -y azure-cli
    return
  fi

  echo "Unsupported Linux distribution for automatic installation." >&2
  exit 1
}

install_azure_cli_macos() {
  log "Installing Azure CLI on macOS via Homebrew..."
  require_cmd brew
  brew update
  brew install azure-cli
}

install_azd() {
  log "Installing Azure Developer CLI (azd)..."
  require_cmd curl
  curl -fsSL https://aka.ms/install-azd.sh | bash
}

install_bicep() {
  log "Installing/updating Bicep CLI via 'az bicep install'..."
  require_cmd az
  az bicep install
}

main() {
  local install_azd_flag=false
  local install_bicep_flag=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cli-only)
        ;;
      --with-azd)
        install_azd_flag=true
        ;;
      --with-bicep)
        install_bicep_flag=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done

  case "$(uname -s)" in
    Linux)
      install_azure_cli_linux
      ;;
    Darwin)
      install_azure_cli_macos
      ;;
    *)
      echo "Unsupported OS: $(uname -s)" >&2
      exit 1
      ;;
  esac

  if $install_azd_flag; then
    install_azd
  fi

  if $install_bicep_flag; then
    install_bicep
  fi

  log "Done. Verify with: az version"
}

main "$@"
