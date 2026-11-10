# pfSense → Splunk (syslog)

pfSense firewall logs feed `index=network` and power the **Stage 1 (port scan)** and
**Stage 6 (network pivot)** detections. pfSense config lives in its web UI / XML, so
this step is manual — there's no shell script to drop in.

## Configure remote syslog

**Status → System Logs → Settings** (scroll to the bottom):

| Setting | Value |
|---|---|
| Enable Remote Logging | ✅ ticked |
| Source Address | `LAN` (e.g. 192.168.1.1) — stops firewall-sourced packets bypassing the send |
| Remote log servers | `SPLUNK_IP:514` (e.g. `192.168.1.103:514`) |
| Remote Syslog Contents | tick **Firewall Events** (add System if wanted) |

Save.

## Verify

pfSense is FreeBSD — its `logger` uses `-h`, **not** `-n` (that's the Linux flag).
**Diagnostics → Command Prompt:**

```sh
logger -h SPLUNK_IP -P 514 "zeus-test-pfsense"
```

Then in Splunk (time = Last 15 min):

```
index=network "zeus-test-pfsense"
```

If real firewall events are already arriving under `index=network sourcetype=pfsense`,
you're done — the manual `logger` test is just a convenience.

## Important: install the pfSense TA on the indexer

Raw pfSense `filterlog` events are positional CSV. Without field extraction, the
network alerts can't read `src_ip` / `dest_ip` / `dest_port` / `proto` / `action`.
Install **"Splunk TA for pfSense"** on the indexer — see `../splunk-apps/README-splunk-tas.md`.
