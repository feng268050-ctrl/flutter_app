## Context

The Android app already uses **`ApiResult`** envelopes and pinned Worker/API origins (**`DeviceApiOriginConfig`**) for **`/v1/...`** calls (for example device AI report and video metadata clients). R2 uploads today may use the **presigned PUT** path under a separate capability; this change adds **STS-backed S3** against **`POST /v1/storage/r2/sts`**. The repository currently has **no** `@aws-sdk/client-s3` Gradle dependency, so implementation must add the minimal AWS SDK v3 modules needed for **`S3Client`** with static credentials + session token on JVM/Android.

## Goals / Non-Goals

**Goals:**

- Call **`POST /v1/storage/r2/sts`** with **`Content-Type: application/json`** and body **`{ "sn", "ttl_seconds" }`**, using the same base URL resolution pattern as other **`/v1`** Worker calls.
- Parse **`ApiResult`** reliably: treat **`success === true`** as logical success; on failure use **`message`** (and avoid assuming HTTP 200 implies success).
- From successful **`data`**, configure **`S3Client`** (or a dedicated factory) with **`endpoint_url`**, **`region`** (`"auto"`), **`access_key_id`**, **`secret_access_key`**, **`session_token`**, and retain **`bucket`** + **`expires_at`** for callers.
- Log **whether STS credentials were obtained** and **whether the S3 client was built**, at INFO or DEBUG, **never** logging secrets, raw keys, or session tokens.

**Non-Goals:**

- Defining the full upload UX (progress UI, retries, multipart tuning) unless required to prove the client works; focus is STS fetch + client construction and logging.
- Changing the presigned-upload spec or removing OSS/other transports.

## Decisions

1. **HTTP stack** — Reuse existing patterns (**OkHttp** direct call or **Retrofit** interface) consistent with **`DeviceWorkerAiReportClient`** / **`DeviceWorkerVideoMetadataClient`**: build URL via **`DeviceApiOriginConfig.joinUnderBase(..., "/v1/storage/r2/sts")`** (or equivalent path join), POST JSON with Gson-serialized body.
2. **Response typing** — Introduce a typed **`ApiResult`-compatible** wrapper or generic + **`R2StsCredentialsData`** DTO matching backend field names (`access_key_id`, `secret_access_key`, `session_token`, `expires_at`, `endpoint_url`, `bucket`, `region`). Map **`session_token`** to AWS SDK’s **`sessionToken`** at client build time.
3. **AWS SDK** — Use **AWS SDK for Kotlin** or **Java v3** `S3Client` depending on project conventions: the user asked for **`@aws-sdk/client-s3`** semantics; on Android/JVM the idiomatic equivalent is **`software.amazon.awssdk:s3`** (and **`auth`**, **`regions`** as needed) with **`StaticCredentialsProvider`** + **`AwsSessionCredentials`**. Document the exact Gradle coordinates in **`tasks.md`** after verifying compatibility with the app’s **`minSdk`** and existing dependency resolution.
4. **Logging** — Use the project’s standard logger (e.g. **`LogTAGConstant`** + **`LogUtils`** / Timber if present) with fixed tags or sub-tags: one line after HTTP parse (success/failure, optional **`expires_at`** for success), one line after **`S3Client`** build (success/failure + non-sensitive error type).
5. **Credential safety** — Do not log request/response bodies; redact any exception messages that might echo network payloads.

## Risks / Trade-offs

- **[Risk] AWS SDK size / desugaring** → Mitigation: depend only on required modules; confirm ProGuard/R8 rules if shrinker strips AWS model classes.
- **[Risk] `region: "auto"`** with custom endpoint → Mitigation: use SDK configuration that accepts explicit endpoint override (same as R2 docs); integration test or manual smoke against staging.
- **[Risk] Clock skew vs `expires_at`** → Mitigation: document that callers should refresh STS before upload if near expiry; optional future helper to compute remaining TTL.

## Migration Plan

- Ship behind no flag if the new client is additive; callers migrate incrementally from presigned/OSS per follow-up tasks.
- Rollback: remove call sites and dependencies if unused; no server migration required on the app side.

## Open Questions

- Whether **`POST /v1/storage/r2/sts`** is served from the **same pinned origin** as **`/v1/devices/...`** in all environments (design assumes yes until disproven).
- Exact **Gradle BOM or version** alignment with other AWS usage if introduced elsewhere later.
