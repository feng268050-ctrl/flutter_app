## REMOVED Requirements

### Requirement: Product.ini file location and format

**Reason:** Superseded by `properties-ini` (`/var/lib/hal/properties.ini`).
**Migration:** Use `properties-ini` requirements; migrate on-disk `product.ini` → `properties.ini` via bind-prefs.

### Requirement: Built-in product identity properties

**Reason:** Moved to `properties-ini` (identity still Vendor Storage; stale ini keys ignored on the new path).
**Migration:** See `properties-ini` “Built-in product identity properties”.

### Requirement: Extended product keys via accessors

**Reason:** Moved to `properties-ini` with empty `camera_ip` = unconfigured.
**Migration:** See `properties-ini` “Extended property keys via accessors”.

### Requirement: Host SN matches ProductInfo sn

**Reason:** Unchanged behavior; owned by `properties-ini` for documentation cohesion with set-prop.
**Migration:** See `properties-ini` “Host SN matches ProductInfo sn”.

### Requirement: Device Information empty display

**Reason:** Moved to `properties-ini`.
**Migration:** See `properties-ini` “Device Information empty display”.

### Requirement: Host make set-prop upserts product.ini

**Reason:** Target file renamed to `properties.ini`.
**Migration:** See `properties-ini` “Host make set-prop upserts properties.ini”.

### Requirement: Host make del-prop removes a product.ini key

**Reason:** Target file renamed to `properties.ini`.
**Migration:** See `properties-ini` “Host make del-prop removes a properties.ini key”.

### Requirement: OEM board pack seeds product.ini

**Reason:** No OEM seed; cameras/tunables are per-unit via set-prop only.
**Migration:** Delete OEM seed files; use `make set-prop` after flash / `write-identity`.

### Requirement: oem-compose merges product.ini seed (identity from OEM)

**Reason:** Compose MUST NOT merge properties/product ini.
**Migration:** Remove `merge_product_ini` from oem-compose; see `properties-ini` “No OEM properties seed”.
