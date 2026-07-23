## 1. Code Package Migration

- [x] 1.1 Scan app source for deprecated lens-guard package references (e.g. `com.lasercyber.lws.ui.lensinspector`) and list impacted files.
- [x] 1.2 Update all lens-guard native bridge imports/usages to `com.lasercyber.lws.ai`.
- [x] 1.3 Verify compilation-level correctness for changed imports (no unresolved symbols). (`./gradlew :app:compileReleaseJavaWithJavac` passed on 2026-04-21)

## 2. Documentation Migration

- [x] 2.1 Update `APP_INTEGRATION_GUIDE.md` package path examples and explanatory text to `com.lasercyber.lws.ai`.
- [x] 2.2 Update `LENS_GUARD_APP_CHANGES.md` and `PROJECT_ARCHITECTURE.md` entries that still reference deprecated package path.
- [x] 2.3 Ensure migration notes clearly state `com.lasercyber.lws.ui.lensinspector` is deprecated and `com.lasercyber.lws.ai` is the only active contract.

## 3. Verification and Delivery

- [x] 3.1 Run repository-wide search: app `*.java` / `*.kt` must not import deprecated lensinspector packages; Markdown may mention them only as deprecation notes.
- [x] 3.2 Runtime smoke is not required for package migration completion in the current build: LensGuard auto-start is gated because the target RK3566 BSP/RKNN runtime is incompatible. Compile/search verification covers the namespace migration; callback parity remains covered by the published package-migration spec for supported runtime environments.
- [x] 3.3 Create/push migration branch to `http://git.lasercyber.com/software/lws-ui` and prepare for merge.
