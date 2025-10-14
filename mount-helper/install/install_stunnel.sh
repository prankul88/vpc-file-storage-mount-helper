#!/bin/bash
set -euo pipefail

INSTALL="install"
UNINSTALL="uninstall"
CONF_FILE=/etc/ibmcloud/share.conf

# Base path:
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PACKAGES_BASE="${SCRIPT_DIR}/packages"

# Temporary: Add a test certificate to /etc/stunnel if stunnel is installed
# This is a non-production test certificate used only during development.
# Once certificates signed by a trusted CA are adopted, this will be removed
# and the trusted CA certs will be preinstalled with the OS.
create_stunnel_cert_if_installed() {
    if command -v stunnel >/dev/null 2>&1 && [ -d /etc/stunnel ]; then
        cat <<EOF > /etc/stunnel/allca.pem
-----BEGIN CERTIFICATE-----
MIIFdTCCA12gAwIBAgIUdNDeiuIBYhInN5rrT+FZPmE5vy4wDQYJKoZIhvcNAQEL
BQAwSjELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMQ8wDQYDVQQHDAZEYWxs
YXMxDDAKBgNVBAoMA0lCTTEMMAoGA1UEAwwDSUJNMB4XDTI1MDUwMTE0NDkxNVoX
DTM1MDQyOTE0NDkxNVowSjELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMQ8w
DQYDVQQHDAZEYWxsYXMxDDAKBgNVBAoMA0lCTTEMMAoGA1UEAwwDSUJNMIICIjAN
BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA4xgsAao3qQc6btAw2fwue/YK7/qm
XmLX+F7ATfqJwnDgshGOSii6LBBa9QHLPL59WLHbz/M3YBk4YJ8MTOAZTH48UyS0
3epYSIpeoE/8wtoGtQoIhhEftNSsPYNixFsDPPyRSR2dvXVJrZZtkwdxrp4M8aAc
wD3hBqCNI2FFPb8d1/OICCweHevz3BvGzAT8HdDo9j8vjH2BSFqm99cyk5iKMdO9
p0LCNPN/uLybNScyzB7aeNRQPHaNEMU5JVHtV+sYrDAeanAmHnMbRnQw8QBOIC3N
jyvB1IAV5Ny884Nb0pZWSWzwXCr3oB6S4YI/O6jQIBhBgG+27R9jWVfgoiS7ezqT
Grc7/n50PdLEMUqyJ6lijzvearACanObnXi6xJup18DYv7aCLwNQn2I7C3KNs7lr
DaFLEEl0xjj/u6ruDYCxe70aGJC2g4s36chvu6BoSaSpl2yU9a1XrfNGfxoVcXvZ
Bwhx+zsWlH3sdIa85lqwvjFg9kh2+JLkAA+7KgINwGeNF8+a05tBbC5N9xOXjOJu
Ok/CCMJ8chQZoJj1JqrKezUZElTG0qJNqVlKyEzJ3boLTAOT6mGurna3ajR5Zijd
7Y8m298ecozO3+WnQtLJQY5jMHJBQjG3l8qfaUybeDSllmypDiOHfS9hn7F85sGh
bupFEHIYP2Y4+UcCAwEAAaNTMFEwHQYDVR0OBBYEFJnWw/hcYcbsRbcSWivW8893
M9TMMB8GA1UdIwQYMBaAFJnWw/hcYcbsRbcSWivW8893M9TMMA8GA1UdEwEB/wQF
MAMBAf8wDQYJKoZIhvcNAQELBQADggIBALhVdmERupJERDAxa8tjv9NyPdLmWKvX
DG4EN9qeuh7lXnTw97tuaAFglXmp//nbqJ1pSUdaTflUnc1bGEiOkRKHfeVEsvbH
AtvFkLWi7CEg/A6ulJ+RgZynssdZ5D5Y+cLw2JhaiDxNf+yikcnn5q0BXpiZCqA6
a0ylPmoDKn1pC2c5s95f7yehXBNDxJw+Lxdec8kKKeNk23HcLei/AoKaKzJQK2Q0
aCFgWdxofvky1h2csCjQN2EJAAp1v0BDBX/GvIkD4dXA9YI8sIeF/ZWv2gxFJNeY
guqcBWTPNwpKNflmz+TqQOB9rNdGDh0WQAQLLeeccOb16hlr86YbDfrjikQFrfcx
KIq9Jj15vsIEmLNavIAANjWOGn/8gNTttyHMYitSAecpqX0VY0/Qe3s0fmMhwJgl
PSEK8nYssZ/7WVpV0RE8qyo0t4M01kl8NXUlWuyZ3vt+Wgz8xYMMvL2b9M7q6ysm
M76z0t8anU9C7BTX8C7THFHid/LRS/1UlvuJKkQYsUgxac+OFcrw32NiZ5QTJ8Z8
0iurNNAwqiVuEKwccwv+dO1qXTQDMf7YmeAwv4iSzG/l4M7F/xBTZEY2MeRjrLQl
62hMSc0o/OkBYCF6O3tXupXJs/5weBNZqcLizEu076XZ4pBhgKXpmJgqfHLRAcwN
6sIG86suxYkB
-----END CERTIFICATE-----
EOF
        echo "Created /etc/stunnel/allca.pem certificate."
    else
        echo "stunnel not installed or /etc/stunnel does not exist; skipping cert creation."
    fi
}

setup_stunnel_directories() {
  local DIR_LIST="/var/run/stunnel4/ /etc/stunnel /var/log/stunnel"
  sudo mkdir -p $DIR_LIST
  sudo chmod 744 $DIR_LIST
}

store_kv() { local k="$1" v="$2"; sudo mkdir -p "$(dirname "$CONF_FILE")"; sudo touch "$CONF_FILE"; sudo sed -i.bak "/^${k}=*/d" "$CONF_FILE"; echo "${k}=${v}" | sudo tee -a "$CONF_FILE" >/dev/null; }
store_stunnel_env(){ store_kv STUNNEL_ENV "${STUNNEL_ENV:-}"; }
store_trusted_ca_file_name(){ store_kv TRUSTED_ROOT_CACERT "$*"; }
store_arch_env(){ store_kv ARCH_ENV "$(uname -m)"; }

install_stunnel_ubuntu_debian() {
  echo "Offline stunnel install (Ubuntu/Debian)…"
  . /etc/os-release
  : "${VERSION_ID:?No VERSION_ID}"
  local PKG_DIR="${PACKAGES_BASE}/ubuntu/${VERSION_ID}"

  [[ -d "$PKG_DIR" ]] || { echo "Missing dir: $PKG_DIR"; exit 1; }

  # Find stunnel .deb 
  shopt -s nullglob
  local debs=( "$PKG_DIR"/stunnel*.deb )
  shopt -u nullglob
  [[ ${#debs[@]} -ge 1 ]] || { echo "No stunnel*.deb in $PKG_DIR"; exit 1; }

  local pick="" best_ver=""
  for f in "${debs[@]}"; do
    ver="$(dpkg-deb -f "$f" Version 2>/dev/null || echo 0)"
    if [ -z "$best_ver" ] || dpkg --compare-versions "$ver" gt "$best_ver"; then
      best_ver="$ver"
      pick="$f"
    fi
  done

  echo "Installing: $pick (Version: $best_ver)"
  sudo apt-get -y install "$pick"

  setup_stunnel_directories
  create_stunnel_cert_if_installed
  store_trusted_ca_file_name "/etc/ssl/certs/ca-certificates.crt"
  store_stunnel_env
  store_arch_env

  command -v stunnel >/dev/null && echo "stunnel installed offline." || { echo "install failed"; exit 1; }
}

# Install stunnel on Red Hat/CentOS/Rocky-based systems
install_stunnel_rhel_centos_rocky() {
    echo "Starting installation of stunnel on Red Hat/CentOS/Rocky-based system..."

    # Install stunnel
    sudo yum install -y stunnel
    setup_stunnel_directories
    create_stunnel_cert_if_installed

    store_trusted_ca_file_name "/etc/pki/tls/certs/ca-bundle.crt"
    store_stunnel_env
    store_arch_env

    # Verify installation
    if command -v stunnel > /dev/null; then
        echo "stunnel installed successfully!"
    else
        echo "Failed to install stunnel."
        exit 1
    fi
}

# Function to install stunnel on SUSE-based systems
install_stunnel_suse() {
    echo "Starting installation of stunnel on SUSE-based system..."
    # Install stunnel
    sudo zypper install -y stunnel
    setup_stunnel_directories
    create_stunnel_cert_if_installed

    store_trusted_ca_file_name  "/etc/ssl/ca-bundle.pem"
    store_stunnel_env

    # Verify installation
    if command -v stunnel > /dev/null; then
        echo "stunnel installed successfully!"
    else
        echo "Failed to install stunnel."
        exit 1
    fi
}

# Uninstall stunnel on Ubuntu/Debian-based systems
uninstall_stunnel_ubuntu_debian() {
  echo "Uninstalling stunnel (Ubuntu/Debian)…"
  sudo apt-get remove --purge -y stunnel4 || true
  sudo rm -rf /var/run/stunnel4/ /etc/stunnel
  command -v stunnel >/dev/null || echo "stunnel uninstalled."
}

# Uninstall stunnel on Red Hat/CentOS/Rocky-based systems
uninstall_stunnel_rhel_centos_rocky() {
  echo "Uninstalling stunnel (RHEL/Rocky/CentOS)…"
  if command -v dnf >/dev/null 2>&1; then sudo dnf remove -y stunnel || true; else sudo yum remove -y stunnel || true; fi
  sudo rm -rf /var/run/stunnel4/ /etc/stunnel
  command -v stunnel >/dev/null || echo "stunnel uninstalled."
}

# Uninstall stunnel on SUSE-based systems
uninstall_stunnel_suse() {
    echo "Uninstalling stunnel on SUSE-based system..."
    sudo zypper remove -y stunnel
    sudo rm -rf /var/run/stunnel4/ /etc/stunnel

    if ! command -v stunnel > /dev/null; then
        echo "stunnel uninstalled successfully!"
    else
        echo "Failed to uninstall stunnel."
        exit 1
    fi
}

# Function to detect the OS and install or uninstall stunnel
detect_and_handle() {
  local ACTION="$1"
  [[ -f /etc/os-release ]] || { echo "/etc/os-release missing"; exit 1; }
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      [[ "$ACTION" == "$INSTALL" ]] && install_stunnel_ubuntu_debian || uninstall_stunnel_ubuntu_debian
      ;;
    centos|rhel|rocky)
      [[ "$ACTION" == "$INSTALL" ]] && install_stunnel_rhel_centos_rocky || uninstall_stunnel_rhel_centos_rocky
      ;;
    *)
      echo "Unsupported OS: $ID"; exit 1;;
  esac
}

# Default action is install
ACTION="$(echo "${1:-$INSTALL}" | tr '[:upper:]' '[:lower:]')"
[[ "$ACTION" == "$INSTALL" || "$ACTION" == "$UNINSTALL" ]] || { echo "Use: install|uninstall"; exit 1; }
detect_and_handle "$ACTION"