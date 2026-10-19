# ADR 0002: Pinned Image Versions

**Date**: 2026-10-19

**Status**: Accepted

## Problem

Should the Home Assistant Docker image be pinned to a specific version or always pull `latest`?

## Decision

Pin the Home Assistant image to a specific version (e.g., `ghcr.io/home-assistant/home-assistant:2024.12.0`) in docker-compose.yml. Store the version in `.env` for easy updates.

## Rationale

- **Reproducibility**: You know exactly which version is running. If something breaks, you can pin it or rollback.
- **Explicit Upgrades**: Upgrades become intentional (edit `.env`, run Ansible upgrade task), not automatic surprises at 3 AM.
- **Testing**: You can test a new version locally before rolling out to the Pi.
- **Home Automation**: Unlike stateless services, HA upgrades can break automations. Pin versions to control the cadence.

## Consequences

- Manual version management required. Set a calendar reminder to check for HA updates periodically.
- The upgrade task becomes the way to bump versions (not just pulling fresh image).
- `.env` must track the current version.

## Alternatives Considered

- `latest` tag (auto-updates): Simpler initially, but risky for home automation. A breaking change could disable automations mid-deployment.
- Latest release by month/year (e.g., `2024.12`): Loses patch-level control; minor bugs could slip in.
