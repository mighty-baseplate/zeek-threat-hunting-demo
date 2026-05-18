# Real-Time Threat Hunting with Zeek

Demo project I built to show network threat detection in action. Two VMs, some Zeek magic, and watch a brute-force attack get detected and blocked in real-time.

## What This Does

Set up two VMs: one attacker (Kali Linux) running SSH brute-force attacks, one SOC box (Ubuntu) running Zeek + ELK. Zeek captures the traffic, logs go into Elasticsearch, and when things get suspicious, a script pops up an alert asking if you want to block the IP.

It's meant for a demo/college expo, but the core detection logic works and can be extended to other attack types (DNS tunneling, HTTP scanning, etc.).

## The Setup

- **Attacker VM**: Kali Linux running Hydra
- **SOC/Victim VM**: Ubuntu 22.04 with Zeek, Elasticsearch/Kibana for logs, custom Bash scripts for alerts
- **What you see**: Terminal logs with colors, real-time monitoring, Kibana dashboards, and pop-up alerts when attacks hit the threshold

## Installation

Make sure you have two VMs set up and on the same network. On Ubuntu:

```bash
sudo apt install zeek elasticsearch kibana filebeat zenity
git clone https://github.com/mighty-baseplate/zeek-threat-hunting-demo
cd zeek-threat-hunting-demo
chmod +x *.sh
```

Configure Zeek to detect SSH brute-force:
```bash
echo '@load protocols/ssh/detect-bruteforcing' | sudo tee -a /opt/zeek/share/zeek/site/local.zeek
sudo zeekctl deploy
```

Set up Filebeat to ship Zeek logs to Elasticsearch. Edit `/etc/filebeat/filebeat.yml`:
```yaml
filebeat.inputs:
- type: log
  paths:
    - /opt/zeek/logs/current/*.log

output.elasticsearch:
  hosts: ["localhost:9200"]
```

Then start everything:
```bash
sudo systemctl start elasticsearch kibana filebeat
```

## Running the Demo

On the Ubuntu box:
```bash
# Terminal 1: Watch SSH attacks in real-time
./zeek-live-monitor.sh

# Terminal 2: Alert on brute-force threshold (>10 failures in 30s)
sudo ./ssh_alert.sh

# Terminal 3: View formatted logs
./zeek-log-viewer.sh ssh
```

On the Kali box:
```bash
hydra -l victim -P /usr/share/wordlists/rockyou.txt ssh://10.54.164.253 -t 16 -V -I
```

Watch the magic:
1. Attacks flood the terminal
2. Kibana dashboard shows the spike
3. Alert pops up
4. Click "Yes" to block the attacker IP with iptables

## Scripts

- **ssh_alert.sh**: Monitors `ssh.log` for failed logins. If >10 failures in 30 seconds, shows a GUI alert and blocks the IP if you confirm.
- **zeek-live-monitor.sh**: Real-time colored view of SSH attacks and all network connections. Good for demos.
- **zeek-log-viewer.sh**: Cleaner formatted output of Zeek logs (connection, SSH, DNS, HTTP). Usage: `./zeek-log-viewer.sh [ssh|conn|dns|http|all]`

## Known Issues / TODO

- The hardcoded Kali IP in `zeek-live-monitor.sh` (192.168.1.12) — update to your actual network setup
- SSH brute-force detection relies on Zeek's built-in `detect-bruteforcing` policy. If that's not triggering, you'll see raw logs but no special alerts
- Block rules (iptables) aren't persistent across reboot — good for demo, but add to `/etc/iptables/rules.v4` if you want to keep them

## License

MIT — Use it however you want.
