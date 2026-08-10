## Context

System OTA previously: (1) cloud tier for API pin, (2) tier→`staging.json`/`release.json` via Worker `/r2/`, (3) host default `-beta`/`staging.json`. Peripherals and product intent are **release-only** on public CDN **`https://cdn.lasercyber.com/`**.

## Goals / Non-Goals

**Goals:**

- Always `{artifact}/release.json` + plain semver on publish.
- Device checks use CDN direct URLs (system + CB + camera).
- Independent of 云服务 / pinned Worker origin.

**Non-Goals:**

- Removing cloud environment tiers for WS/registration.
- Deleting historical R2 `staging.json` objects.
- Changing Ed25519 verify or A/B apply.

## Decisions

### 1. Release-only publish

Always `release.json` + `v{semver}.tar.gz`; die if `RELEASE` is set.

### 2. CDN manifest URLs

App resolves:
- `https://cdn.lasercyber.com/lws-hmi/release.json`
- `https://cdn.lasercyber.com/lws-hmi/control-board/release.json`
- `https://cdn.lasercyber.com/lws-hmi/camera/release.json`

Package download still uses manifest `url` (presign `public_url`, typically CDN).

### 3. Legacy prerelease compare may remain in `cyber_ota`

Publish does not emit `-beta`; parser/compare MAY still accept legacy strings.

## Risks / Trade-offs

- **[CDN 404 until republish]** → Operators must `make publish` so CDN has `release.json`.
- **[CI still sets RELEASE=]** → Fail-fast with migration message.

## Migration Plan

1. Ship App CDN resolvers + host release-only publish together.
2. Ensure CDN has current `lws-hmi/release.json` (and peripheral manifests as needed).
3. Archive this change after specs sync to `openspec/specs/`.

## Open Questions

- None.
