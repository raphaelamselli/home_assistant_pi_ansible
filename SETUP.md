# Home Assistant Setup Checklist

This is a step-by-step guide to set up Home Assistant on your Raspberry Pi using the automated Ansible playbook.

## Prerequisites Checklist

Before you start, verify you have:

- [ ] **Raspberry Pi 4** (8 GB RAM) with Raspberry Pi OS installed
- [ ] **External SSD** attached and mounted (e.g., at `/mnt/ssd`)
- [ ] **Docker + Docker Compose** installed on the Pi
  - To verify: SSH into Pi and run `docker --version` and `docker compose version`
- [ ] **SSH access** from your laptop to the Pi
  - To test: `ssh pi@<pi-ip>`
- [ ] **Ansible** installed on your laptop
  - To verify: `ansible --version`
- [ ] **Git** installed on your laptop (to clone this repo)

If any prerequisite is missing, refer to the links in [README.md](README.md).

---

## Step 1: Prepare the Repository

```bash
# Clone this repository
git clone <repo-url> home-assistant
cd home-assistant

# Copy the example configuration
cp .env.example .env

# Edit .env with your preferred settings (optional, defaults are fine for first run)
# nano .env
```

**What to check:**
- [ ] `.env` file exists (copy of `.env.example`)
- [ ] `HA_VERSION` is set (default: `2024.12.0`)
- [ ] `SSD_PATH` matches your Pi's SSD mount point (default: `/mnt/ssd`)

---

## Step 2: Verify SSD Mount on the Pi

SSH into the Pi and verify the SSD is properly mounted:

```bash
ssh pi@<pi-ip>
df -h | grep /mnt/ssd
```

You should see the SSD listed. If not, mount it first or update `SSD_PATH` in `.env`.

**What to check:**
- [ ] SSD is mounted at the path specified in `.env`
- [ ] SSD has sufficient free space (at least 20 GB recommended)

---

## Step 3: Create Ansible Inventory File

Create `ansible/inventory.ini` on your laptop:

```bash
mkdir -p ansible
cat > ansible/inventory.ini << EOF
[homeassistant]
pi_host ansible_host=<pi-ip-or-hostname> ansible_user=pi
EOF
```

Replace `<pi-ip-or-hostname>` with:
- **IP address** (e.g., `192.168.1.100`), or
- **Hostname** (e.g., `raspberry-pi.local`)

**What to check:**
- [ ] `ansible/inventory.ini` file created
- [ ] Correct Pi IP or hostname in the file
- [ ] SSH user is `pi` (or change if different on your setup)

---

## Step 4: Test Ansible Connectivity

From your laptop, verify Ansible can reach the Pi:

```bash
cd ansible
ansible all -i inventory.ini -m ping
```

Expected output:
```
pi_host | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

**What to check:**
- [ ] Ping is successful (no SSH errors)
- [ ] If ping fails, verify: correct IP/hostname, SSH key setup, firewall rules

---

## Step 5: Run the Ansible Playbook

Run the setup playbook from your laptop:

```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

The playbook will:
1. Verify Python 3, Docker, Docker Compose
2. Create `homeassistant` user and group
3. Install git
4. Set up SSD directories
5. Open port 8123 in firewall (if ufw is active)
6. Render `docker-compose.yml` from template
7. Pull the Home Assistant Docker image
8. Start the container
9. Wait for Home Assistant to respond

**Expected runtime: 3–5 minutes** (first pull of Docker image takes time)

**What to check:**
- [ ] No errors during playbook execution
- [ ] All tasks show `ok` or `changed` status
- [ ] Final output prints "✓ Home Assistant is responding on port 8123"

---

## Step 6: Verify Home Assistant is Running

Check the container is running:

```bash
ssh pi@<pi-ip>
docker ps | grep homeassistant
```

You should see the `homeassistant` container listed as `Up`.

**What to check:**
- [ ] Container is running (status `Up`)
- [ ] Container is named `homeassistant`

---

## Step 7: First-Time Web UI Setup

Open your browser and navigate to:

```
http://<pi-ip>:8123
```

You should see the Home Assistant onboarding screen.

**First-run steps:**

1. [ ] Create your admin user (username + password)
2. [ ] Set your location (for weather, sunrise/sunset automations)
3. [ ] Set your timezone
4. [ ] Complete onboarding (you can skip device discovery for now)

**Note:** First-time load may take 30–60 seconds as HA initializes its database.

---

## Step 8: Add Integrations (Optional)

Home Assistant is now running with a bare minimum setup. To add integrations:

1. Go to **Settings > Devices & Services**
2. Click **Create Automation**
3. Choose an integration (e.g., MQTT, Zigbee, Philips Hue, etc.)
4. Follow the integration's setup instructions

---

## Post-Setup: Ongoing Maintenance

### Check Logs

View container logs:

```bash
docker logs homeassistant
docker logs -f homeassistant  # Follow logs in real-time
```

### Upgrade Home Assistant

To upgrade to a new version:

1. Update `HA_VERSION` in `.env` to the new version
2. Run the playbook again: `ansible-playbook -i inventory.ini playbook.yml`
3. Brief downtime (~10–30 seconds) while container restarts

### Backup Configuration

Backup your Home Assistant setup before major changes:

```bash
ssh pi@<pi-ip>
tar -czf homeassistant-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/homeassistant/
# Download backup to your laptop (optional)
scp pi@<pi-ip>:~/homeassistant-backup-*.tar.gz .
```

---

## Troubleshooting

If something goes wrong:

1. Check [docs/troubleshooting.md](docs/troubleshooting.md)
2. Review playbook output for error messages
3. Check container logs: `docker logs homeassistant`
4. Re-run the playbook—it's idempotent and safe to run multiple times

---

## Next Steps

- [ ] Customize Home Assistant via web UI
- [ ] Add integrations for your smart home devices
- [ ] Create automations
- [ ] Set up backups (manual or automated)
- [ ] Review [docs/troubleshooting.md](docs/troubleshooting.md) for advanced topics

---

**All steps complete?** You're ready to build your home automation! 🚀
