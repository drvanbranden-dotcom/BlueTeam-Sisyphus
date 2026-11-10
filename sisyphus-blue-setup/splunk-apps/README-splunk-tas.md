# Splunk Technology Add-ons (TAs)

TAs give Splunk the field extractions the alerts depend on. Install them on the
**indexer** (and the Linux TA also on the Universal Forwarders, if you want parsing
at the source). Both are hosted on the internal TAFE server (`https://www.tafe.mst`)
alongside the forwarder downloads.

| TA | Install on | Why it matters |
|---|---|---|
| **Splunk TA for pfSense** | indexer (192.168.1.103) | Extracts `src_ip` / `dest_ip` / `dest_port` / `proto` / `action` from `filterlog`. **Stage 1 & 6 network alerts need this.** |
| **Splunk TA for Linux** (`Splunk_TA_nix`) | indexer (+ forwarders) | Normalises auditd / process data for the Stage 4/5/8/9 host alerts. |

## Install (indexer, Windows)

1. Download the TA (`.spl` / `.tgz`) from the Splunk Files page.
2. Splunk Web → **Apps → Manage Apps → Install app from file** → upload the TA → **Restart Splunk**.

   Or drop it into `C:\Program Files\Splunk\etc\apps\` and restart:
   ```
   cd "C:\Program Files\Splunk\bin"
   splunk restart
   ```

## Install (forwarder, Linux — optional)

```bash
sudo tar xzf Splunk_TA_nix-*.tgz -C /opt/splunkforwarder/etc/apps
sudo /opt/splunkforwarder/bin/splunk restart
```

> Our alert SPL is written with `rex` fallbacks so it still works without the TAs,
> but the pfSense TA in particular makes the Stage 1/6 network rules far more reliable.
> Grab it whenever you build a fresh environment.
