/* SPDX-License-Identifier: BSD-2-Clause */
/*
 * LWS HAL Secrets seal TA — UUID shared by CA and TA.
 */
#ifndef SEAL_TA_H
#define SEAL_TA_H

/* b8e4f2a1-9c3d-4e6f-8a1b-2c3d4e5f6071 */
#define TA_SEAL_UUID { 0xb8e4f2a1, 0x9c3d, 0x4e6f, \
	{ 0x8a, 0x1b, 0x2c, 0x3d, 0x4e, 0x5f, 0x60, 0x71 } }

/*
 * CMD_PROBE — no params; returns TEE_SUCCESS if TA is alive.
 */
#define TA_SEAL_CMD_PROBE	0

/*
 * CMD_SEAL
 *  in[0]  memref INPUT  plaintext
 *  in[1]  memref INPUT  aad
 *  out[2] memref OUTPUT opaque blob (magic|ver|nonce|ct|tag)
 */
#define TA_SEAL_CMD_SEAL	1

/*
 * CMD_UNSEAL
 *  in[0]  memref INPUT  opaque blob
 *  in[1]  memref INPUT  aad (must match seal)
 *  out[2] memref OUTPUT plaintext
 */
#define TA_SEAL_CMD_UNSEAL	2

/*
 * CMD_DERIVE_PROBE — spike / diagnostics: derive TA-unique HUK key twice,
 * compare, return 32 bytes on OUTPUT[0] if both match (for determinism check).
 * Production wrap MUST NOT export this key to REE except as ciphertext wrap.
 */
#define TA_SEAL_CMD_DERIVE_PROBE	3

/*
 * CMD_KEK_EXPORT_WRAP
 *  out[0] memref OUTPUT  LWSK wrap blob (load-or-create REE KEK, then wrap)
 */
#define TA_SEAL_CMD_KEK_EXPORT_WRAP	4

/*
 * CMD_KEK_IMPORT_WRAP
 *  in[0] memref INPUT  LWSK wrap blob → unwrap → write REE FS KEK object
 */
#define TA_SEAL_CMD_KEK_IMPORT_WRAP	5

#define TA_SEAL_BLOB_MAGIC0	'L'
#define TA_SEAL_BLOB_MAGIC1	'W'
#define TA_SEAL_BLOB_MAGIC2	'S'
#define TA_SEAL_BLOB_MAGIC3	'1'
#define TA_SEAL_BLOB_VERSION	1
#define TA_SEAL_NONCE_LEN	12
#define TA_SEAL_TAG_LEN		16
#define TA_SEAL_KEY_LEN		32
#define TA_SEAL_MAX_PLAIN	(64 * 1024)
#define TA_SEAL_HDR_LEN		(4 + 1 + TA_SEAL_NONCE_LEN)

/* HUK-wrapped seal KEK blob (Vendor Storage ID 23). */
#define TA_KEK_WRAP_MAGIC0	'L'
#define TA_KEK_WRAP_MAGIC1	'W'
#define TA_KEK_WRAP_MAGIC2	'S'
#define TA_KEK_WRAP_MAGIC3	'K'
#define TA_KEK_WRAP_VERSION	1
#define TA_KEK_WRAP_HDR_LEN	(4 + 1 + TA_SEAL_NONCE_LEN)
#define TA_KEK_WRAP_LEN		(TA_KEK_WRAP_HDR_LEN + TA_SEAL_KEY_LEN + TA_SEAL_TAG_LEN)
#define TA_KEK_WRAP_AAD		"seal-kek-wrap-v1"
#define TA_KEK_WRAP_AAD_LEN	15

#endif /* SEAL_TA_H */
