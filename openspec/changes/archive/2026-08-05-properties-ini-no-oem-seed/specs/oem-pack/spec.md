## REMOVED Requirements

### Requirement: OEM product.ini is not per-unit identity authority

**Reason:** OEM MUST NOT ship `product.ini` / `properties.ini` at all; identity is Vendor Storage; tunables are runtime-only via `properties-ini`.
**Migration:** Delete `oem/boards/*/product.ini`; see `properties-ini` “No OEM properties seed”.

## ADDED Requirements

### Requirement: OEM packs do not ship properties.ini

OEM board packs MUST NOT include `product.ini` or `properties.ini`. Board profiles MUST NOT rely on a `helpers.camera_ip` value as a product-wide default camera host. `oem-compose` MUST NOT write `/var/lib/hal/properties.ini`.

#### Scenario: ynh960 board pack has no ini seed

- **WHEN** inspecting `oem/boards/ynh960/` after this change
- **THEN** the directory MUST NOT contain `product.ini` or `properties.ini`
