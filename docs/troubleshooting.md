# Troubleshooting Guide

Common issues and solutions for Home Assistant on Docker on Raspberry Pi.

---

## Ansible Playbook Issues

### Ansible Connection Error

**Problem:** `Failed to connect to the host via ssh`

**Causes & Solutions:**
- [ ] Verify the Pi IP/hostname is correct in `inventory.ini`
- [ ] Verify SSH is running on the Pi: `ssh pi@<pi-ip>` from your laptop
- [ ] Check firewall rules on the Pi (port 22 should be open)
- [ ] Verify SSH user is correct (usually `pi`, unless you changed it)
- [ ] Ensure SSH key or password authentication is configured

**Command to test:**
```bash
ssh -v pi@<pi-ip>
```

---

### Ansible Task Fails: Python 3 Not Found

**Problem:** `"No module named 'json'"`

**Solution:** Ensure Python 3 is installed on the Pi:
```bash
ssh pi@<pi-ip>
python3 --version
```

If not installed, manually install:
```bash
sudo apt update && sudo apt install python3 python3-pip
```

---

### Ansible Task Fails: Docker Not Installed

**Problem:** `"docker: command not found"`

**Solution:** Install Docker on the Pi:
```bash
ssh pi@<pi-ip>
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker pi
```

---

### Ansible Task Fails: Docker Compose Not Installed

**Problem:** `"docker: 'compose' is not a docker command"`

**Solution:** Install Docker Compose v2:
```bash
ssh pi@<pi-ip>
sudo apt install docker-compose
# or
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

---

### Ansible Task Fails: Port 8123 Already in Use

**Problem:** `"Port 8123 is already in use by another process"`

**Solution:**
1. [ ] Identify what's using port 8123:
   ```bash
   ssh pi@<pi-ip>
   netstat -tuln | grep 8123
   ```

2. [ ] Either:
   - Stop the service using port 8123, or
   - Change `HA_PORT` in `.env` to an unused port (e.g., `8124`)

3. [ ] Re-run the playbook

---

## Docker & Container Issues

### Home Assistant Container Won't Start

**Problem:** Container appears in `docker ps` but exits immediately

**Diagnosis:**
```bash
ssh pi@<pi-ip>
docker logs homeassistant
```

**Common causes & solutions:**

- **Permissions error**: Data directory not owned by `homeassistant` user
  ```bash
  sudo chown -R homeassistant:homeassistant /mnt/ssd/homeassistant
  docker restart homeassistant
  ```

- **Corrupted database**: Recreate the named volume
  ```bash
  docker compose down
  docker volume rm ha_homeassistant_data
  docker compose up -d
  ```

---

### Port 8123 Not Responding

**Problem:** `http://<pi-ip>:8123` times out or connection refused

**Diagnosis:**
```bash
ssh pi@<pi-ip>
docker ps | grep homeassistant
docker logs homeassistant
```

**Solutions:**

1. [ ] Verify container is running: `docker ps | grep homeassistant`
2. [ ] Check logs for errors: `docker logs homeassistant`
3. [ ] Verify port mapping: `docker port homeassistant` should show `8123/tcp`
4. [ ] Check firewall: Ensure port 8123 is open
5. [ ] Verify network: `docker network inspect bridge`

---

### High Memory or CPU Usage

**Problem:** Home Assistant container consuming excessive resources

**Diagnosis:**
```bash
docker stats homeassistant
```

**Solutions:**

- **First run database init**: Wait 5–10 minutes on first boot; HA may be compacting the database
- **Too many integrations**: Disable unused integrations via web UI (Settings > Devices & Services)
- **Database corruption**: Backup `/mnt/ssd/homeassistant/home-assistant_v2.db`, delete it, and restart:
  ```bash
  ssh pi@<pi-ip>
  mv /mnt/ssd/homeassistant/home-assistant_v2.db /mnt/ssd/homeassistant/home-assistant_v2.db.bak
  docker restart homeassistant
  ```

---

## SSD & Storage Issues

### SSD Mount Point Not Found

**Problem:** Playbook fails with `"SSD path does not exist"`

**Solution:**
1. [ ] SSH into the Pi and verify SSD is mounted:
   ```bash
   ssh pi@<pi-ip>
   df -h | grep /mnt/ssd
   ```

2. [ ] If not mounted, mount it:
   ```bash
   sudo mkdir -p /mnt/ssd
   # Find the device (e.g., /dev/sda1)
   lsblk
   # Mount (adjust device and filesystem type as needed)
   sudo mount -t ext4 /dev/sda1 /mnt/ssd
   ```

3. [ ] Update `SSD_PATH` in `.env` to match your mount point

---

### SSD Running Out of Space

**Problem:** Home Assistant runs out of disk space

**Diagnosis:**
```bash
ssh pi@<pi-ip>
df -h /mnt/ssd
```

**Solutions:**

- [ ] Clean old logs:
  ```bash
  ssh pi@<pi-ip>
  rm /mnt/ssd/logs/*.log*
  ```

- [ ] Prune old Home Assistant database:
  - Go to Settings > System > Logs & Debugging > Purge
  - Select how many days of history to keep

- [ ] Expand SSD (if possible) or migrate to larger drive

---

## Network & Firewall Issues

### Firewall Blocking Port 8123

**Problem:** Can't reach Home Assistant from another device on the network

**Solution:**
1. [ ] Verify port is open in ufw (if active):
   ```bash
   ssh pi@<pi-ip>
   sudo ufw status numbered
   ```

2. [ ] If 8123 is not listed, open it:
   ```bash
   sudo ufw allow 8123/tcp
   ```

3. [ ] Test connectivity:
   ```bash
   curl -I http://<pi-ip>:8123
   ```

---

### Reverse Proxy / DNS Issues

**Problem:** Can access HA locally (`http://pi-ip:8123`) but not from outside network

**Solution:** This is a more advanced setup. Check:
1. [ ] Router port forwarding is configured
2. [ ] Dynamic DNS (if using domain name) is up-to-date
3. [ ] HTTPS/SSL certificate is configured (if accessing via domain)

See [Home Assistant Documentation on Remote Access](https://www.home-assistant.io/docs/remote/) for details.

---

## Data & Backup Issues

### Want to Backup Before Major Change

**Command:**
```bash
ssh pi@<pi-ip>
tar -czf homeassistant-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/homeassistant/
# Download to your laptop
scp pi@<pi-ip>:~/homeassistant-backup-*.tar.gz .
```

---

### Need to Restore from Backup

**Command:**
```bash
# Upload backup to Pi
scp homeassistant-backup-20241019.tar.gz pi@<pi-ip>:~

# SSH into Pi and extract
ssh pi@<pi-ip>
docker stop homeassistant
rm -rf /mnt/ssd/homeassistant/*
tar -xzf ~/homeassistant-backup-20241019.tar.gz -C /
docker start homeassistant
```

---

## Upgrade Issues

### Upgrade Fails or Container Won't Start After Upgrade

**Problem:** After bumping `HA_VERSION` in `.env` and running playbook, container won't start

**Solution:**
1. [ ] Check logs:
   ```bash
   docker logs homeassistant
   ```

2. [ ] If database is corrupted, try backing up and purging:
   ```bash
   ssh pi@<pi-ip>
   mv /mnt/ssd/homeassistant/home-assistant_v2.db /mnt/ssd/homeassistant/home-assistant_v2.db.bak
   docker compose down
   docker compose up -d
   ```

3. [ ] If persistent, rollback by reverting `HA_VERSION` in `.env` and re-running playbook

---

## Getting Help

- [ ] Check [Home Assistant Documentation](https://www.home-assistant.io/)
- [ ] Review container logs: `docker logs homeassistant`
- [ ] Run playbook in verbose mode: `ansible-playbook -i inventory.ini playbook.yml -vv`
- [ ] Check official [Home Assistant Community Forums](https://community.home-assistant.io/)

---

**Still stuck?** Double-check the Prerequisites section in [SETUP.md](../SETUP.md) and re-run the Ansible playbook—it's safe to run multiple times.
