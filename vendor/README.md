# Vendor Android modules

Gradle library modules vendored in-repo (not published to Maven). **Do not treat these as app dead-code targets** — see `docs/java-kotlin-dead-code-audit.md` (vendored policy).

| Directory | Gradle project | Upstream / role |
|-----------|----------------|-----------------|
| `easydarwin/` | `:vendor:easydarwin` | EasyDarwin RTSP client, `EasyPlayerClient`, recording mux |
| `modbus4j/` | `:vendor:modbus4j` | Serotonin Modbus4J protocol stack |
| `modbus4android/` | `:vendor:modbus4android` | Android serial + Modbus RTU wrapper (depends on modbus4j) |
| `ynhapi/` | `:vendor:ynhapi` | Innohi YNH tablet hardware API (`YNHAPI-20250310.jar`); see [`ynhapi/API.md`](ynhapi/API.md) |

**Not here:** runtime bundled assets (`app/src/main/assets/ai-library/`), native AI build tree (`native/lensinspector/`), or Maven dependencies in `app/build.gradle.kts`.
