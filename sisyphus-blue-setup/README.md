# Project Sisyphus — Blue Team Lab Setup

Automated setup for the **Book of Zeus** Blue Team telemetry pipeline (IRTx / VU23220 /
VU23221). Stands up Splunk and the log forwarding for every machine so a fresh VM
environment is wired for detection in minutes instead of an afternoon.

> Authorised TAFE lab / isolated test environment use only.

## Topology

```
  Red Kali (203.0.113.x)
        │  attack
        ▼
  pfSense ── syslog/514 ─────────────┐
        │                            ▼
  DMZ Apache host  ── UF/9997 ──►  Splunk indexer  (index: network / web / os)
  (10.1.1.x)                       (192.168.1.103)
        │ pivot                       ▲
        ▼                             │
  Internal host    ── UF/9997 ────────┘
  (192.168.1.x)
```

## Repo layout — set up each machine from its own folder

| Folder | Machine | What it does |
|---|---|---|
| `splunk-indexer-windows/` | Splunk Enterprise (Windows) | `setup-splunk-indexer.ps1` — indexes, 9997 receiver, 514 syslog input, firewall |
| `dmz-apache-ubuntu/` | DMZ / vulnerable Apache host | `setup-forwarder-dmz.sh` — UF + Apache & OS logs + auditd watches |
| `internal-ubuntu/` | Internal pivot target | `setup-forwarder-internal.sh` — UF + OS logs + auditd watches |
| `pfsense/` | pfSense firewall | `README-pfsense-syslog.md` — manual remote-syslog steps (UI-only) |
| `splunk-apps/` | indexer / forwarders | `README-splunk-tas.md` — pfSense & Linux TAs for field extraction |

## Order of operations

1. **Indexer first** — install Splunk (MSI), then run `setup-splunk-indexer.ps1` (as Admin).
2. **TAs** — install the pfSense + Linux TAs on the indexer (`splunk-apps/`).
3. **pfSense** — point remote syslog at the indexer (`pfsense/`).
4. **Forwarders** — run the matching `setup-forwarder-*.sh` on each Ubuntu host.
5. **Verify** — on the indexer, each of these should return data:
   ```
   index=network sourcetype=pfsense
   index=web sourcetype=access_combined
   index=os sourcetype=linux_secure
   index=os sourcetype=linux_audit
   ```

## Before you run — edit the CONFIG block at the top of each script

Set at minimum:
- `SPLUNK_IP` — the indexer's IP on the new network
- `UF_URL` + `DOWNLOAD_USER` — where the Universal Forwarder `.tgz` is served (the TAFE
  `www.tafe.mst` server needs DNS set to the lab DNS IP; the forwarder is a **`.tgz`**, not a `.deb`)
- `APACHE_LOG_DIR` (DMZ script) — if Apache logs somewhere other than `/usr/local/apache2/logs`

## Notes baked in from real setup

- Universal Forwarder on Linux is the **`.tgz`** → extract to `/opt`, **not** `dpkg`.
- Forwarder runs **as root** (`-user root`) so it can read `/var/log/auth.log` and
  `/var/log/audit/audit.log` — otherwise the OS alerts get no data.
- The lab image already ships auditd **execve** rules (`cmd_exec` / `root_cmd_exec` /
  `wget_exec`). auditd de-dupes syscall rules by syscall (not key), so the scripts add
  only **file watches** and `auditctl -D` + `augenrules --load` to avoid the
  "Rule exists" abort. Alert SPL uses `cmd_exec` / `root_cmd_exec` / `wget_exec` for
  command execution and `zeus_*` for file reads.
- Don't commit real credentials — the scripts prompt for the Splunk admin password
  (or read it from the `SPLUNK_ADMIN_PASS` env var) instead of hard-coding it.
```bash
chmod +x dmz-apache-ubuntu/setup-forwarder-dmz.sh internal-ubuntu/setup-forwarder-internal.sh
```
