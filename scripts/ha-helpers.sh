#!/bin/bash
# Home Assistant Helper Commands
# Convenient shortcuts for common operations

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
ANSIBLE_DIR="$REPO_ROOT/ansible"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_help() {
    cat << EOF
${BLUE}Home Assistant Helper Commands${NC}

Usage: ./scripts/ha-helpers.sh <command> [options]

${GREEN}Setup & Installation:${NC}
  setup              Run initial Ansible playbook to set up Home Assistant
  setup --verbose    Run setup with verbose Ansible output (-vv)

${GREEN}Upgrade & Management:${NC}
  upgrade            Upgrade Home Assistant to the version in .env
  logs               Tail Home Assistant container logs
  logs pi            Tail logs on the Pi (requires SSH)
  status             Show Home Assistant container status

${GREEN}Backup & Recovery:${NC}
  backup             Create a backup of HA config and data
  backup <hostname>  Create backup on a specific Pi

${GREEN}Configuration:${NC}
  edit-env           Open .env file in editor
  edit-inventory     Open inventory.ini file in editor
  show-env           Display current .env settings

${GREEN}Diagnostics:${NC}
  test-ssh           Test SSH connection to the Pi
  check-deps         Verify dependencies (ansible, docker, etc.)

${RED}Other:${NC}
  help               Show this help message

${BLUE}Examples:${NC}
  ./scripts/ha-helpers.sh setup
  ./scripts/ha-helpers.sh upgrade
  ./scripts/ha-helpers.sh logs
  ./scripts/ha-helpers.sh backup
EOF
}

check_deps() {
    echo -e "${BLUE}Checking dependencies...${NC}"
    local missing=0

    if ! command -v ansible &> /dev/null; then
        echo -e "${RED}✗ ansible not found${NC}"
        missing=1
    else
        echo -e "${GREEN}✓ $(ansible --version | head -1)${NC}"
    fi

    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}ℹ docker not found (OK if using remote Pi)${NC}"
    else
        echo -e "${GREEN}✓ Docker: $(docker --version)${NC}"
    fi

    if [ $missing -eq 1 ]; then
        echo -e "${RED}Missing dependencies. See README.md for installation.${NC}"
        exit 1
    fi
}

setup() {
    echo -e "${BLUE}Running Home Assistant setup...${NC}"

    if [ ! -f "$REPO_ROOT/.env" ]; then
        echo -e "${RED}Error: .env file not found${NC}"
        echo "Run: cp .env.example .env"
        exit 1
    fi

    if [ ! -f "$ANSIBLE_DIR/inventory.ini" ]; then
        echo -e "${RED}Error: inventory.ini not found${NC}"
        echo "Run: cp ansible/inventory.example.ini ansible/inventory.ini"
        echo "Then edit with your Pi's IP/hostname"
        exit 1
    fi

    local verbose_flag=""
    if [ "$1" == "--verbose" ]; then
        verbose_flag="-vv"
    fi

    cd "$ANSIBLE_DIR"
    ansible-playbook -i inventory.ini playbook.yml $verbose_flag
}

upgrade() {
    echo -e "${BLUE}Upgrading Home Assistant...${NC}"

    if [ ! -f "$REPO_ROOT/.env" ]; then
        echo -e "${RED}Error: .env file not found${NC}"
        exit 1
    fi

    echo "Before upgrading, ensure you have backed up your configuration:"
    echo "  ./scripts/ha-helpers.sh backup"
    echo ""
    read -p "Continue with upgrade? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    cd "$ANSIBLE_DIR"
    ansible-playbook -i inventory.ini upgrade.yml
}

logs() {
    local target="${1:-docker}"

    if [ "$target" == "docker" ]; then
        docker logs -f homeassistant
    elif [ "$target" == "pi" ]; then
        # Get Pi host from inventory
        local pi_host=$(grep "ansible_host=" "$ANSIBLE_DIR/inventory.ini" | head -1 | sed 's/.*ansible_host=//' | cut -d' ' -f1)
        if [ -z "$pi_host" ]; then
            echo -e "${RED}Error: Could not find Pi host in inventory.ini${NC}"
            exit 1
        fi
        ssh "${pi_host}" docker logs -f homeassistant
    else
        echo -e "${RED}Unknown target: $target${NC}"
        echo "Usage: logs [docker|pi]"
        exit 1
    fi
}

status() {
    echo -e "${BLUE}Home Assistant Container Status:${NC}"
    docker ps --filter "name=homeassistant" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    echo -e "${BLUE}Container Stats:${NC}"
    docker stats --no-stream homeassistant 2>/dev/null || echo "Container not running"
}

backup() {
    local hostname="${1:-}"
    local pi_host="$hostname"

    if [ -z "$pi_host" ]; then
        # Try to get from inventory
        pi_host=$(grep "ansible_host=" "$ANSIBLE_DIR/inventory.ini" | head -1 | sed 's/.*ansible_host=//' | cut -d' ' -f1)
    fi

    if [ -z "$pi_host" ]; then
        echo -e "${RED}Error: No hostname specified and couldn't find one in inventory.ini${NC}"
        exit 1
    fi

    local backup_name="homeassistant-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo -e "${BLUE}Creating backup: $backup_name${NC}"

    ssh "$pi_host" "tar -czf /tmp/$backup_name /mnt/ssd/homeassistant/"
    scp "$pi_host:/tmp/$backup_name" "./$backup_name"
    ssh "$pi_host" "rm /tmp/$backup_name"

    echo -e "${GREEN}✓ Backup created: ./$backup_name${NC}"
}

test_ssh() {
    # Get Pi host from inventory
    local pi_host=$(grep "ansible_host=" "$ANSIBLE_DIR/inventory.ini" | head -1 | sed 's/.*ansible_host=//' | cut -d' ' -f1)
    local pi_user=$(grep "ansible_user=" "$ANSIBLE_DIR/inventory.ini" | head -1 | sed 's/.*ansible_user=//' | cut -d' ' -f1)

    if [ -z "$pi_host" ]; then
        echo -e "${RED}Error: Could not find Pi host in inventory.ini${NC}"
        exit 1
    fi

    echo -e "${BLUE}Testing SSH connection to $pi_host...${NC}"
    if ssh -o ConnectTimeout=5 "$pi_user@$pi_host" "echo 'SSH connection successful' && uname -a"; then
        echo -e "${GREEN}✓ SSH connection successful${NC}"
    else
        echo -e "${RED}✗ SSH connection failed${NC}"
        exit 1
    fi
}

edit_env() {
    ${EDITOR:-nano} "$REPO_ROOT/.env"
}

edit_inventory() {
    ${EDITOR:-nano} "$ANSIBLE_DIR/inventory.ini"
}

show_env() {
    echo -e "${BLUE}Current .env settings:${NC}"
    if [ -f "$REPO_ROOT/.env" ]; then
        grep -v '^#' "$REPO_ROOT/.env" | grep -v '^$'
    else
        echo -e "${RED}.env file not found${NC}"
        exit 1
    fi
}

# Main command dispatch
case "${1:-help}" in
    setup)
        check_deps
        setup "$2"
        ;;
    upgrade)
        check_deps
        upgrade
        ;;
    logs)
        logs "$2"
        ;;
    status)
        status
        ;;
    backup)
        backup "$2"
        ;;
    test-ssh)
        test_ssh
        ;;
    check-deps)
        check_deps
        ;;
    edit-env)
        edit_env
        ;;
    edit-inventory)
        edit_inventory
        ;;
    show-env)
        show_env
        ;;
    help)
        print_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        print_help
        exit 1
        ;;
esac
