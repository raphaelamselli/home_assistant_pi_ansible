# Repository Guidelines

## Project Purpose

Automated setup of Home Assistant in Docker on a Raspberry Pi 4 (8 GB RAM, external SSD), coexisting with other containerized services, using Ansible playbooks for reproducible, idempotent deployments.

## Key Architecture

- **Host**: Raspberry Pi 4 with existing Raspberry Pi OS (not Home Assistant OS)
- **Storage**: External SSD at `/mnt/ssd` with bind mount to `/mnt/ssd/homeassistant`
- **Orchestration**: Docker Compose (pinned versions, templated via Ansible)
- **User**: Unprivileged `homeassistant` user for security isolation
- **Network**: Shared Docker bridge; port 8123 exposed for web UI
- **Automation**: Ansible playbook runs from laptop via SSH; idempotent and re-runnable

## Documentation Structure

- **README.md**: North star—overview, prerequisites, quick start
- **SETUP.md**: Step-by-step checklist for actual deployment
- **GLOSSARY.md**: Domain terminology (Compose, role, volume, etc.)
- **docs/adr/**: Architecture Decision Records (why we chose Docker Compose, pinned versions, unprivileged user)
- **docs/troubleshooting.md**: Common issues and solutions
- **CLAUDE.md**: Claude Code project instructions

## Quick Reference

- **Initial setup**: `./scripts/ha-helpers.sh setup`
- **Upgrade HA version**: Update `HA_VERSION` in `.env`, then `./scripts/ha-helpers.sh upgrade`
- **Check logs**: `./scripts/ha-helpers.sh logs`
- **Backup**: `./scripts/ha-helpers.sh backup`

## Ansible Playbook Structure

```
ansible/
├── playbook.yml                    # Main setup playbook
├── upgrade.yml                     # Upgrade playbook (stop/pull/start)
├── inventory.ini                   # Hosts file (you create from example)
├── inventory.example.ini           # Template with instructions
├── requirements.txt                # Ansible collections (community.docker)
├── vars/main.yml                   # Playbook variables
├── roles/
│   └── homeassistant/
│       └── tasks/main.yml          # Role tasks (check/install/configure)
└── templates/
    └── docker-compose.yml.j2       # Docker Compose template (Jinja2)
```

## Implementation Details

### Main Playbook Tasks (playbook.yml)
1. Load and parse `.env` file for version and paths
2. Run `homeassistant` role (see below)
3. Print completion info with access URL

### Homeassistant Role Tasks (roles/homeassistant/tasks/main.yml)
1. Check/install/upgrade Python 3
2. Verify Docker + Docker Compose installed
3. Create `homeassistant` user and group
4. Install git
5. Create/set permissions on `/mnt/ssd/homeassistant` and `/mnt/ssd/logs/`
6. Configure firewall (ufw) if active
7. Verify port 8123 is available
8. Render docker-compose.yml from template
9. Pull Docker image
10. Start container via docker-compose
11. Wait for healthcheck to pass

### Docker Compose Template (templates/docker-compose.yml.j2)
- Image: `ghcr.io/home-assistant/home-assistant:{{ ha_version }}`
- User: unprivileged `{{ ha_user }}` (homeassistant)
- Volumes: Named volume → bind mount to `/mnt/ssd/homeassistant`
- Healthcheck: Polls `http://localhost:8123` every 30s
- Logging: JSON driver, rotated (max 10 MB, 3 files)
- Network: Shared bridge for inter-container communication

## Configuration Files

- **.env.example**: Template with `HA_VERSION`, `SSD_PATH`, `HA_PORT`
- **.env**: Git-ignored runtime config (user creates from example)
- **.gitignore**: Excludes `docker-compose.yml` (build artifact), `.env`, logs

## Development & Customization

To modify:
- **HA version**: Edit `HA_VERSION` in `.env`
- **SSD path**: Edit `SSD_PATH` in `.env` (if not at `/mnt/ssd`)
- **Port**: Edit `HA_PORT` in `.env`
- **Playbook logic**: Edit `ansible/roles/homeassistant/tasks/main.yml`
- **Docker config**: Edit `ansible/templates/docker-compose.yml.j2`

## Helper Scripts

Run `./scripts/ha-helpers.sh help` for available commands:
- `setup`: Run initial Ansible playbook
- `upgrade`: Upgrade to new HA version
- `logs`: Tail container logs
- `status`: Show container status
- `backup`: Create backup
- `test-ssh`: Verify SSH connection
- `check-deps`: Verify Ansible/Docker installed

## Key Decisions (ADRs)

- **ADR-0001**: Docker Compose for reproducibility, idempotency, and simplicity
- **ADR-0002**: Pinned image versions for explicit, safe upgrades
- **ADR-0003**: Unprivileged user for security isolation from root and other services

## When to Use Skills & Agents

- **Troubleshooting**: Use `/diagnosing-bugs` for container/network issues
- **Enhancements**: Use `/nw-design` for architecture changes
- **Research**: Use `/research` for Home Assistant patterns or new integrations
- **Code review**: Use `/code-review` for Ansible playbook changes
