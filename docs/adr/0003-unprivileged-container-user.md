# ADR 0003: Unprivileged Container User

**Date**: 2026-10-19

**Status**: Accepted

## Problem

Should the Home Assistant container run as root or as an unprivileged user?

## Decision

Run the container as a dedicated unprivileged `homeassistant` user (UID/GID assigned by Ansible). This user owns `/mnt/ssd/homeassistant` and all HA data.

## Rationale

- **Security**: If the container is ever compromised, the attacker is confined to the `homeassistant` user's permissions. Cannot escalate to root or access other containers' data.
- **Isolation**: Other containers running on the Pi have separate users/permissions. A breach in HA doesn't spill into other services.
- **Supported**: The official Home Assistant Docker image supports running as unprivileged (includes all necessary capabilities).
- **Best Practice**: Running containers as root is a known risk. Unprivileged is standard in production deployments.

## Consequences

- Ansible must create the `homeassistant` user and group upfront.
- All volume mounts must be chowned to `homeassistant:homeassistant`.
- Docker Compose must specify `user: homeassistant:homeassistant` in the service definition.
- Slightly more complex, but negligible overhead.

## Alternatives Considered

- Run as root: Simpler, but unnecessary risk. Not acceptable for shared host.
- Run as existing user (e.g., `pi` or `ubuntu`): Mixes concerns; harder to audit permissions.
