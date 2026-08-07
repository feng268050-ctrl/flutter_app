/* SPDX-License-Identifier: BSD-2-Clause */
/*
 * secrets-seal-ca — OP-TEE client for LWS HAL Secrets.
 * Protocol (stdin JSON / stdout one line b64):
 *   probe | seal | unseal
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <tee_client_api.h>

#include <seal_ta.h>

static const TEEC_UUID ta_uuid = TA_SEAL_UUID;

static const char b64_table[] =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static int b64_encode(const uint8_t *in, size_t in_len, char **out_str)
{
	size_t out_cap = 4 * ((in_len + 2) / 3) + 1;
	char *out;
	size_t i = 0;
	size_t j = 0;

	out = malloc(out_cap);
	if (!out)
		return -1;
	for (; i + 3 <= in_len; i += 3) {
		uint32_t triple = ((uint32_t)in[i] << 16) |
				  ((uint32_t)in[i + 1] << 8) | in[i + 2];

		out[j++] = b64_table[(triple >> 18) & 63];
		out[j++] = b64_table[(triple >> 12) & 63];
		out[j++] = b64_table[(triple >> 6) & 63];
		out[j++] = b64_table[triple & 63];
	}
	if (in_len % 3 == 1) {
		uint32_t triple = (uint32_t)in[in_len - 1] << 16;

		out[j++] = b64_table[(triple >> 18) & 63];
		out[j++] = b64_table[(triple >> 12) & 63];
		out[j++] = '=';
		out[j++] = '=';
	} else if (in_len % 3 == 2) {
		uint32_t triple = ((uint32_t)in[in_len - 2] << 16) |
				  ((uint32_t)in[in_len - 1] << 8);

		out[j++] = b64_table[(triple >> 18) & 63];
		out[j++] = b64_table[(triple >> 12) & 63];
		out[j++] = b64_table[(triple >> 6) & 63];
		out[j++] = '=';
	}
	out[j] = '\0';
	*out_str = out;
	return 0;
}

static int b64_val(char c)
{
	if (c >= 'A' && c <= 'Z')
		return c - 'A';
	if (c >= 'a' && c <= 'z')
		return c - 'a' + 26;
	if (c >= '0' && c <= '9')
		return c - '0' + 52;
	if (c == '+')
		return 62;
	if (c == '/')
		return 63;
	return -1;
}

static int b64_decode(const char *in, uint8_t **out_buf, size_t *out_len)
{
	size_t len = strlen(in);
	size_t i, j;
	uint8_t *out;

	while (len && (in[len - 1] == '\n' || in[len - 1] == '\r' ||
		       in[len - 1] == '='))
		len--;
	/* recount with padding for size estimate */
	len = strlen(in);
	while (len && (in[len - 1] == '\n' || in[len - 1] == '\r'))
		len--;

	out = malloc(len / 4 * 3 + 3);
	if (!out)
		return -1;
	j = 0;
	for (i = 0; i + 4 <= len; i += 4) {
		int a = b64_val(in[i]);
		int b = b64_val(in[i + 1]);
		int c = in[i + 2] == '=' ? 0 : b64_val(in[i + 2]);
		int d = in[i + 3] == '=' ? 0 : b64_val(in[i + 3]);

		if (a < 0 || b < 0 || (in[i + 2] != '=' && c < 0) ||
		    (in[i + 3] != '=' && d < 0)) {
			free(out);
			return -1;
		}
		out[j++] = (uint8_t)((a << 2) | (b >> 4));
		if (in[i + 2] != '=')
			out[j++] = (uint8_t)(((b & 15) << 4) | (c >> 2));
		if (in[i + 3] != '=')
			out[j++] = (uint8_t)(((c & 3) << 6) | d);
	}
	*out_buf = out;
	*out_len = j;
	return 0;
}

static char *read_stdin_all(void)
{
	size_t cap = 4096;
	size_t n = 0;
	char *buf = malloc(cap);
	ssize_t r;

	if (!buf)
		return NULL;
	while ((r = read(STDIN_FILENO, buf + n, cap - n - 1)) > 0) {
		n += (size_t)r;
		if (n + 1 >= cap) {
			cap *= 2;
			char *nb = realloc(buf, cap);

			if (!nb) {
				free(buf);
				return NULL;
			}
			buf = nb;
		}
	}
	buf[n] = '\0';
	return buf;
}

/* Extract JSON string value for "key":"value" (no escapes). */
static int json_get_string(const char *json, const char *key, char **out)
{
	char pat[128];
	const char *p;
	const char *q;
	size_t len;

	snprintf(pat, sizeof(pat), "\"%s\"", key);
	p = strstr(json, pat);
	if (!p)
		return -1;
	p = strchr(p + strlen(pat), '"');
	if (!p)
		return -1;
	p++;
	q = strchr(p, '"');
	if (!q)
		return -1;
	len = (size_t)(q - p);
	*out = malloc(len + 1);
	if (!*out)
		return -1;
	memcpy(*out, p, len);
	(*out)[len] = '\0';
	return 0;
}

static int cmd_probe(void)
{
	TEEC_Result res;
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_Operation op;
	uint32_t origin = 0;

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "secrets-seal-ca: InitializeContext 0x%x\n", res);
		return 1;
	}
	res = TEEC_OpenSession(&ctx, &sess, &ta_uuid, TEEC_LOGIN_PUBLIC, NULL,
			       NULL, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: OpenSession 0x%x origin 0x%x\n", res,
			origin);
		TEEC_FinalizeContext(&ctx);
		return 1;
	}
	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_NONE, TEEC_NONE, TEEC_NONE,
					 TEEC_NONE);
	res = TEEC_InvokeCommand(&sess, TA_SEAL_CMD_PROBE, &op, &origin);
	TEEC_CloseSession(&sess);
	TEEC_FinalizeContext(&ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "secrets-seal-ca: probe 0x%x origin 0x%x\n", res,
			origin);
		return 1;
	}
	return 0;
}

static int cmd_derive_probe(void)
{
	TEEC_Result res;
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_Operation op;
	uint32_t origin = 0;
	uint8_t key[TA_SEAL_KEY_LEN];
	uint8_t key2[TA_SEAL_KEY_LEN];
	char *b64 = NULL;
	int rc = 1;

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "secrets-seal-ca: InitializeContext 0x%x\n", res);
		return 1;
	}
	res = TEEC_OpenSession(&ctx, &sess, &ta_uuid, TEEC_LOGIN_PUBLIC, NULL,
			       NULL, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: OpenSession 0x%x origin 0x%x\n", res,
			origin);
		TEEC_FinalizeContext(&ctx);
		return 1;
	}

	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_OUTPUT, TEEC_NONE,
					 TEEC_NONE, TEEC_NONE);
	op.params[0].tmpref.buffer = key;
	op.params[0].tmpref.size = sizeof(key);
	res = TEEC_InvokeCommand(&sess, TA_SEAL_CMD_DERIVE_PROBE, &op, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: derive-probe 0x%x origin 0x%x\n", res,
			origin);
		goto done;
	}
	op.params[0].tmpref.buffer = key2;
	op.params[0].tmpref.size = sizeof(key2);
	res = TEEC_InvokeCommand(&sess, TA_SEAL_CMD_DERIVE_PROBE, &op, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: derive-probe2 0x%x origin 0x%x\n", res,
			origin);
		goto done;
	}
	if (memcmp(key, key2, sizeof(key)) != 0) {
		fprintf(stderr, "secrets-seal-ca: derive-probe non-deterministic\n");
		goto done;
	}
	if (b64_encode(key, sizeof(key), &b64))
		goto done;
	printf("DERIVE_OK %s\n", b64);
	rc = 0;

done:
	TEEC_CloseSession(&sess);
	TEEC_FinalizeContext(&ctx);
	free(b64);
	return rc;
}

static int cmd_kek_export_wrap(void)
{
	TEEC_Result res;
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_Operation op;
	uint32_t origin = 0;
	uint8_t out[TA_KEK_WRAP_LEN];
	char *b64 = NULL;
	int rc = 1;

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "secrets-seal-ca: InitializeContext 0x%x\n", res);
		return 1;
	}
	res = TEEC_OpenSession(&ctx, &sess, &ta_uuid, TEEC_LOGIN_PUBLIC, NULL,
			       NULL, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: OpenSession 0x%x origin 0x%x\n", res,
			origin);
		TEEC_FinalizeContext(&ctx);
		return 1;
	}
	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_OUTPUT, TEEC_NONE,
					 TEEC_NONE, TEEC_NONE);
	op.params[0].tmpref.buffer = out;
	op.params[0].tmpref.size = sizeof(out);
	res = TEEC_InvokeCommand(&sess, TA_SEAL_CMD_KEK_EXPORT_WRAP, &op,
				 &origin);
	TEEC_CloseSession(&sess);
	TEEC_FinalizeContext(&ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: kek-export-wrap 0x%x origin 0x%x\n",
			res, origin);
		return 1;
	}
	if (b64_encode(out, op.params[0].tmpref.size, &b64))
		return 1;
	puts(b64);
	free(b64);
	return 0;
}

static int cmd_kek_import_wrap(void)
{
	TEEC_Result res;
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_Operation op;
	uint32_t origin = 0;
	char *raw = NULL;
	char *blob_b64 = NULL;
	uint8_t *blob = NULL;
	size_t blob_len = 0;
	int rc = 1;

	raw = read_stdin_all();
	if (!raw) {
		fprintf(stderr, "secrets-seal-ca: empty stdin\n");
		return 1;
	}
	/* Prefer JSON; else treat entire stdin (trimmed) as b64. */
	if (json_get_string(raw, "blob_b64", &blob_b64) == 0) {
		/* ok */
	} else {
		char *p = raw;
		size_t n;

		while (*p == ' ' || *p == '\n' || *p == '\r' || *p == '\t')
			p++;
		n = strlen(p);
		while (n && (p[n - 1] == '\n' || p[n - 1] == '\r' ||
			     p[n - 1] == ' '))
			n--;
		blob_b64 = malloc(n + 1);
		if (!blob_b64)
			goto done;
		memcpy(blob_b64, p, n);
		blob_b64[n] = '\0';
	}
	if (b64_decode(blob_b64, &blob, &blob_len)) {
		fprintf(stderr, "secrets-seal-ca: bad b64 wrap blob\n");
		goto done;
	}

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "secrets-seal-ca: InitializeContext 0x%x\n", res);
		goto done;
	}
	res = TEEC_OpenSession(&ctx, &sess, &ta_uuid, TEEC_LOGIN_PUBLIC, NULL,
			       NULL, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: OpenSession 0x%x origin 0x%x\n", res,
			origin);
		TEEC_FinalizeContext(&ctx);
		goto done;
	}
	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_INPUT, TEEC_NONE,
					 TEEC_NONE, TEEC_NONE);
	op.params[0].tmpref.buffer = blob;
	op.params[0].tmpref.size = blob_len;
	res = TEEC_InvokeCommand(&sess, TA_SEAL_CMD_KEK_IMPORT_WRAP, &op,
				 &origin);
	TEEC_CloseSession(&sess);
	TEEC_FinalizeContext(&ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: kek-import-wrap 0x%x origin 0x%x\n",
			res, origin);
		goto done;
	}
	rc = 0;

done:
	free(raw);
	free(blob_b64);
	free(blob);
	return rc;
}

static int cmd_seal_unseal(int seal)
{
	TEEC_Result res;
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_Operation op;
	uint32_t origin = 0;
	char *json = NULL;
	char *in_b64 = NULL;
	char *aad_b64 = NULL;
	uint8_t *in = NULL;
	uint8_t *aad = NULL;
	uint8_t *out = NULL;
	size_t in_len = 0;
	size_t aad_len = 0;
	size_t out_len = 0;
	char *out_b64 = NULL;
	int rc = 1;
	const char *in_key = seal ? "plaintext_b64" : "blob_b64";

	json = read_stdin_all();
	if (!json || json_get_string(json, in_key, &in_b64) ||
	    json_get_string(json, "aad_b64", &aad_b64) ||
	    b64_decode(in_b64, &in, &in_len) ||
	    b64_decode(aad_b64, &aad, &aad_len)) {
		fprintf(stderr, "secrets-seal-ca: bad JSON/b64 input\n");
		goto done;
	}

	out_len = seal ? (TA_SEAL_HDR_LEN + in_len + TA_SEAL_TAG_LEN + 64)
		       : (in_len + 64);
	out = malloc(out_len);
	if (!out)
		goto done;

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "secrets-seal-ca: InitializeContext 0x%x\n", res);
		goto done;
	}
	res = TEEC_OpenSession(&ctx, &sess, &ta_uuid, TEEC_LOGIN_PUBLIC, NULL,
			       NULL, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr,
			"secrets-seal-ca: OpenSession 0x%x origin 0x%x\n", res,
			origin);
		TEEC_FinalizeContext(&ctx);
		goto done;
	}

	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_INPUT,
					 TEEC_MEMREF_TEMP_INPUT,
					 TEEC_MEMREF_TEMP_OUTPUT, TEEC_NONE);
	op.params[0].tmpref.buffer = in;
	op.params[0].tmpref.size = in_len;
	op.params[1].tmpref.buffer = aad_len ? aad : (void *)"";
	op.params[1].tmpref.size = aad_len;
	op.params[2].tmpref.buffer = out;
	op.params[2].tmpref.size = out_len;

	res = TEEC_InvokeCommand(&sess,
				 seal ? TA_SEAL_CMD_SEAL : TA_SEAL_CMD_UNSEAL,
				 &op, &origin);
	if (res == TEEC_ERROR_SHORT_BUFFER) {
		size_t need = op.params[2].tmpref.size;
		uint8_t *nb = realloc(out, need);

		if (!nb) {
			TEEC_CloseSession(&sess);
			TEEC_FinalizeContext(&ctx);
			goto done;
		}
		out = nb;
		out_len = need;
		op.params[2].tmpref.buffer = out;
		op.params[2].tmpref.size = out_len;
		res = TEEC_InvokeCommand(&sess,
					 seal ? TA_SEAL_CMD_SEAL
					      : TA_SEAL_CMD_UNSEAL,
					 &op, &origin);
	}
	TEEC_CloseSession(&sess);
	TEEC_FinalizeContext(&ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "secrets-seal-ca: %s 0x%x origin 0x%x\n",
			seal ? "seal" : "unseal", res, origin);
		goto done;
	}
	out_len = op.params[2].tmpref.size;
	if (b64_encode(out, out_len, &out_b64))
		goto done;
	puts(out_b64);
	rc = 0;

done:
	free(json);
	free(in_b64);
	free(aad_b64);
	free(in);
	free(aad);
	free(out);
	free(out_b64);
	return rc;
}

int main(int argc, char **argv)
{
	if (argc != 2) {
		fprintf(stderr,
			"usage: secrets-seal-ca {probe|seal|unseal|derive-probe|kek-export-wrap|kek-import-wrap}\n");
		return 2;
	}
	if (!strcmp(argv[1], "probe"))
		return cmd_probe();
	if (!strcmp(argv[1], "seal"))
		return cmd_seal_unseal(1);
	if (!strcmp(argv[1], "unseal"))
		return cmd_seal_unseal(0);
	if (!strcmp(argv[1], "derive-probe"))
		return cmd_derive_probe();
	if (!strcmp(argv[1], "kek-export-wrap"))
		return cmd_kek_export_wrap();
	if (!strcmp(argv[1], "kek-import-wrap"))
		return cmd_kek_import_wrap();
	fprintf(stderr,
		"usage: secrets-seal-ca {probe|seal|unseal|derive-probe|kek-export-wrap|kek-import-wrap}\n");
	return 2;
}
