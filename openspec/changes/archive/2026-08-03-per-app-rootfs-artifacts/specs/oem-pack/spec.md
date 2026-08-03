## MODIFIED Requirements

### Requirement: Factory packaging includes OEM for resolved SKU

`make build-img` SHALL package the resolved `oem.img` into the factory artifact written under `output/firmware/<APP>/<factory_sku>/factory.img` (default `APP=lws_hmi`), and SHALL write a sibling `manifest.txt` recording resolved `app`, `uboot_id`, `oem_id`, and build identity. During migration, `output/firmware/update.img` MAY be a symlink (or copy) to the selected/default APP + sku's `factory.img`.

#### Scenario: factory.img packs oem

- **WHEN** `make build-oem` then `make build-img` succeed for default APP and `ynh960-p800`
- **THEN** `output/firmware/lws_hmi/ynh960-p800/factory.img` exists and the package includes the oem partition payload
