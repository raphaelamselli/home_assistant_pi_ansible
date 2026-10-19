# ADR 0001: Docker Compose over Plain Docker Run

**Date**: 2026-10-19

**Status**: Accepted

## Problem

How should we orchestrate the Home Assistant container?

## Decision

Use Docker Compose (docker-compose.yml) to define and manage the HA service, rather than `docker run` commands or other orchestration tools.

## Rationale

- **Reproducibility**: The entire service definition (image, volumes, ports, healthcheck) lives in one versioned file. Easy to re-run setup identically.
- **Idempotency**: `docker-compose up` is idempotent. Running it twice produces the same state; no manual drift.
- **Upgrades**: Bumping the image version in one line and re-running `docker-compose pull && docker-compose up` is simpler than scripting docker run flags.
- **Familiarity**: Compose is standard for single-host deployments. Lower cognitive load for future maintainers.
- **Not Overkill**: Kubernetes is overkill for a single Pi. Plain docker run is fragile and error-prone.

## Consequences

- Requires Docker Compose installed on the Pi (handled by Ansible).
- Ansible templates the Compose file (adds a layer of indirection, but enables parameterization).
- Config changes require editing the template or regenerating from Ansible, not manual Compose tweaks.

## Alternatives Considered

- Plain `docker run` commands: Simpler but fragile, hard to upgrade, not idempotent.
- Kubernetes: Overkill for one Pi, huge operational overhead.
- systemd timer + shell script: Low-level, less portable, harder to maintain.
