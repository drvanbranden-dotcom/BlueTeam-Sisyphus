#!/usr/bin/env bash
#
# Project Sisyphus — Blue Team telemetry setup
# TARGET: DMZ / vulnerable Apache host (e.g. 10.1.1.10, "dmzUbuntu")
# Installs the Splunk Universal Forwarder, points it at the indexer,
# forwards Apache + OS logs, and loads the auditd file-watch rules.
#
# Run on the DMZ Ubuntu host:   sudo ./setup-forwarder-dmz.sh
# (It calls sudo internally; run as a normal user with sudo rights.)

set -uo pipefail

### ================= EDIT THESE PER ENVIRONMENT =================
SPLUNK_IP="192.168.1.103"                 # Splunk indexer IP
FWD_PORT="9997"                           # indexer receiving port
UF_URL=""                                 # URL to splunkforwarder-*.tgz (e.g. https://www.tafe.mst/splunkforwarder-10.0.1-Linux-x86_64.tgz)
                                          #   leave blank if a splunkforwarder-*.tgz is already in this folder
DOWNLOAD_USER=""                          # HTTP basic-auth user for UF_URL (blank = no auth). You'll be prompted for the password.
APACHE_LOG_DIR="/usr/local/apache2/logs"  # where access_log / error_log live (source-compiled Apache 2.4.49)
### =============================================================

SPLUNK_HOME="/opt/splunkforwarder"
SPLUNK="$SPLUNK_HOME/bin/splunk"
say(){ echo -e "\n[*] $*"; }

# --- admin password (used to seed first start + authenticate CLI) ---
: "${SPLUNK_ADMIN_PASS:=}"
if [[ -z "$SPLUNK_ADMIN_PASS" ]]; then
  read -s -p "Splunk forwarder admin password to set/use: " SPLUNK_ADMIN_PASS; echo
fi

# --- 1. obtain + extract the Universal Forwarder (.tgz) ---
if [[ ! -x "$SPLUNK" ]]; then
  TGZ="$(ls splunkforwarder-*.tgz 2>/dev/null | head -n1 || true)"
  if [[ -z "$TGZ" && -n "$UF_URL" ]]; then
    say "Downloading forwarder from $UF_URL"
    if [[ -n "$DOWNLOAD_USER" ]]; then
      wget --no-check-certificate --user="$DOWNLOAD_USER" --ask-password -O splunkforwarder.tgz "$UF_URL"
    else
      wget --no-check-certificate -O splunkforwarder.tgz "$UF_URL"
    fi
    TGZ="splunkforwarder.tgz"
  fi
  [[ -z "$TGZ" ]] && { echo "ERROR: no splunkforwarder-*.tgz found and UF_URL is blank."; exit 1; }
  say "Extracting $TGZ to /opt"
  sudo tar xzf "$TGZ" -C /opt
else
  say "Forwarder already installed at $SPLUNK_HOME — skipping download."
fi

# --- 2. seed admin creds for a non-interactive first start ---
if [[ ! -f "$SPLUNK_HOME/etc/passwd" ]]; then
  sudo tee "$SPLUNK_HOME/etc/system/local/user-seed.conf" >/dev/null <<EOF
[user_info]
USERNAME = admin
PASSWORD = $SPLUNK_ADMIN_PASS
EOF
fi

# --- 3. first start + accept licence ---
say "Starting forwarder"
sudo "$SPLUNK" start --accept-license --answer-yes --no-prompt

# --- 4. point at the indexer ---
say "Adding forward-server ${SPLUNK_IP}:${FWD_PORT}"
sudo "$SPLUNK" add forward-server "${SPLUNK_IP}:${FWD_PORT}" -auth "admin:${SPLUNK_ADMIN_PASS}"

# --- 5. run as root on boot (needs root to read auth.log / audit.log) ---
say "Enabling boot-start as root"
sudo "$SPLUNK" stop
sudo "$SPLUNK" enable boot-start -user root || sudo "$SPLUNK" enable boot-start -user root -systemd-managed 1
sudo "$SPLUNK" start

# --- 6. inputs.conf (Apache web logs + OS logs) ---
say "Writing inputs.conf (web + os)"
sudo tee "$SPLUNK_HOME/etc/system/local/inputs.conf" >/dev/null <<EOF
[monitor://${APACHE_LOG_DIR}/access_log]
sourcetype = access_combined
index = web

[monitor://${APACHE_LOG_DIR}/error_log]
sourcetype = apache_error
index = web

[monitor:///var/log/auth.log]
sourcetype = linux_secure
index = os

[monitor:///var/log/audit/audit.log]
sourcetype = linux_audit
index = os
EOF

# --- 7. auditd file-watch rules ---
# NOTE: command execution (execve) is usually ALREADY captured by the lab baseline
# rules (keys: cmd_exec / root_cmd_exec / wget_exec). auditd de-duplicates syscall
# rules by syscall (not key), so re-adding execve throws "Rule exists" and aborts the
# load. We therefore add ONLY the file watches, and flush+reload so nothing collides.
say "Installing auditd + zeus file-watch rules"
sudo apt-get install -y auditd >/dev/null 2>&1 || sudo apt-get install -y auditd
sudo tee /etc/audit/rules.d/zeus.rules >/dev/null <<'EOF'
-w /etc/passwd -p r -k zeus_sensitive
-w /etc/shadow -p r -k zeus_sensitive
-w /var/www/html -p r -k zeus_webread
-w /etc/sudoers -p wa -k zeus_sudoers
-w /etc/sudoers.d -p wa -k zeus_sudoers
-w /home -p r -k zeus_home
EOF
sudo auditctl -D || true
sudo augenrules --load || true

# --- 8. restart forwarder to pick up inputs + report ---
say "Restarting forwarder"
sudo "$SPLUNK" restart
echo
echo "================= DONE (DMZ Apache host) ================="
sudo "$SPLUNK" list forward-server 2>/dev/null || true
echo "auditd rules loaded:"
sudo auditctl -l | grep zeus_ || echo "  (no zeus_ watches — check output above)"
echo "Verify on Splunk (${SPLUNK_IP}):  index=web OR index=os host=$(hostname)"
echo "========================================================="
