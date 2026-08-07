/* SPDX-License-Identifier: BSD-2-Clause */
#include <tee_internal_api.h>
#include <tee_internal_api_extensions.h>

#include <pta_system.h>
#include <seal_ta.h>
#include <string.h>

static const char kek_obj_id[] = "lws-seal-kek-v1";

static TEE_Result load_or_create_kek(TEE_ObjectHandle *key_out)
{
	TEE_Result res;
	TEE_ObjectHandle obj = TEE_HANDLE_NULL;
	TEE_ObjectHandle key = TEE_HANDLE_NULL;
	uint8_t kek[TA_SEAL_KEY_LEN];
	uint32_t read_bytes = 0;
	TEE_Attribute attr;
	uint32_t flags = TEE_DATA_FLAG_ACCESS_READ |
			 TEE_DATA_FLAG_ACCESS_WRITE |
			 TEE_DATA_FLAG_ACCESS_WRITE_META |
			 TEE_DATA_FLAG_SHARE_READ;

	/*
	 * REE FS cache under tee-supplicant -f parent (e.g. /userdata/tee).
	 * Durable source of truth is HUK-wrapped KEK in Vendor Storage (CA
	 * kek-import-wrap / kek-export-wrap). RPMB remains unavailable on
	 * vendor BL32 (STORAGE_NOT_AVAILABLE).
	 */
	res = TEE_OpenPersistentObject(TEE_STORAGE_PRIVATE,
				       kek_obj_id, sizeof(kek_obj_id) - 1,
				       flags, &obj);
	if (res == TEE_SUCCESS) {
		res = TEE_ReadObjectData(obj, kek, sizeof(kek), &read_bytes);
		TEE_CloseObject(obj);
		if (res != TEE_SUCCESS || read_bytes != sizeof(kek)) {
			EMSG("kek read failed 0x%x", res);
			return (res != TEE_SUCCESS) ? res : TEE_ERROR_CORRUPT_OBJECT;
		}
	} else if (res == TEE_ERROR_ITEM_NOT_FOUND) {
		TEE_GenerateRandom(kek, sizeof(kek));
		flags |= TEE_DATA_FLAG_OVERWRITE;
		res = TEE_CreatePersistentObject(TEE_STORAGE_PRIVATE,
						 kek_obj_id,
						 sizeof(kek_obj_id) - 1,
						 flags,
						 TEE_HANDLE_NULL,
						 kek, sizeof(kek),
						 &obj);
		if (res != TEE_SUCCESS) {
			EMSG("kek create failed 0x%x", res);
			return res;
		}
		TEE_CloseObject(obj);
	} else {
		EMSG("kek open failed 0x%x", res);
		return res;
	}

	res = TEE_AllocateTransientObject(TEE_TYPE_AES, TA_SEAL_KEY_LEN * 8,
					  &key);
	if (res != TEE_SUCCESS)
		return res;

	TEE_InitRefAttribute(&attr, TEE_ATTR_SECRET_VALUE, kek, sizeof(kek));
	res = TEE_PopulateTransientObject(key, &attr, 1);
	if (res != TEE_SUCCESS) {
		TEE_FreeTransientObject(key);
		return res;
	}

	*key_out = key;
	return TEE_SUCCESS;
}

static TEE_Result ae_crypt(uint32_t mode,
			   TEE_ObjectHandle key,
			   const uint8_t *nonce, uint32_t nonce_len,
			   const uint8_t *aad, uint32_t aad_len,
			   const uint8_t *in, uint32_t in_len,
			   uint8_t *out, uint32_t *out_len,
			   uint8_t *tag, uint32_t *tag_len)
{
	TEE_Result res;
	TEE_OperationHandle op = TEE_HANDLE_NULL;
	uint32_t tmp_len = *out_len;

	res = TEE_AllocateOperation(&op, TEE_ALG_AES_GCM, mode,
				    TA_SEAL_KEY_LEN * 8);
	if (res != TEE_SUCCESS)
		return res;

	res = TEE_SetOperationKey(op, key);
	if (res != TEE_SUCCESS)
		goto out;

	res = TEE_AEInit(op, nonce, nonce_len, TA_SEAL_TAG_LEN * 8,
			 aad_len, in_len);
	if (res != TEE_SUCCESS)
		goto out;

	if (aad_len)
		TEE_AEUpdateAAD(op, aad, aad_len);

	if (mode == TEE_MODE_ENCRYPT) {
		res = TEE_AEEncryptFinal(op, in, in_len, out, &tmp_len,
					 tag, tag_len);
	} else {
		res = TEE_AEDecryptFinal(op, in, in_len, out, &tmp_len,
					 tag, *tag_len);
	}
	if (res == TEE_SUCCESS)
		*out_len = tmp_len;

out:
	TEE_FreeOperation(op);
	return res;
}

static TEE_Result cmd_probe(uint32_t types, TEE_Param params[4])
{
	(void)params;
	if (types != TEE_PARAM_TYPES(TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE,
				     TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE))
		return TEE_ERROR_BAD_PARAMETERS;
	return TEE_SUCCESS;
}

static TEE_Result derive_ta_unique_key(uint8_t *key, uint32_t key_len)
{
	TEE_Result res;
	TEE_TASessionHandle sess = TEE_HANDLE_NULL;
	uint32_t ret_orig = 0;
	TEE_Param params[4];
	uint32_t param_types =
		TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
				TEE_PARAM_TYPE_MEMREF_OUTPUT,
				TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE);

	res = TEE_OpenTASession(&(const TEE_UUID)PTA_SYSTEM_UUID,
				TEE_TIMEOUT_INFINITE, 0, NULL, &sess,
				&ret_orig);
	if (res != TEE_SUCCESS) {
		EMSG("system PTA open 0x%x origin 0x%x", res, ret_orig);
		return res;
	}

	TEE_MemFill(params, 0, sizeof(params));
	params[0].memref.buffer = NULL;
	params[0].memref.size = 0;
	params[1].memref.buffer = key;
	params[1].memref.size = key_len;

	res = TEE_InvokeTACommand(sess, TEE_TIMEOUT_INFINITE,
				  PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY,
				  param_types, params, &ret_orig);
	if (res != TEE_SUCCESS)
		EMSG("DERIVE_TA_UNIQUE_KEY 0x%x origin 0x%x", res, ret_orig);

	TEE_CloseTASession(sess);
	return res;
}

static TEE_Result cmd_derive_probe(uint32_t types, TEE_Param params[4])
{
	const uint32_t expect =
		TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_OUTPUT,
				TEE_PARAM_TYPE_NONE,
				TEE_PARAM_TYPE_NONE,
				TEE_PARAM_TYPE_NONE);
	TEE_Result res;
	uint8_t k1[TA_SEAL_KEY_LEN];
	uint8_t k2[TA_SEAL_KEY_LEN];

	if (types != expect)
		return TEE_ERROR_BAD_PARAMETERS;
	if (!params[0].memref.buffer ||
	    params[0].memref.size < TA_SEAL_KEY_LEN)
		return TEE_ERROR_SHORT_BUFFER;

	res = derive_ta_unique_key(k1, sizeof(k1));
	if (res != TEE_SUCCESS)
		return res;
	res = derive_ta_unique_key(k2, sizeof(k2));
	if (res != TEE_SUCCESS)
		return res;
	if (TEE_MemCompare(k1, k2, sizeof(k1)) != 0) {
		EMSG("derive probe: non-deterministic key");
		return TEE_ERROR_SECURITY;
	}

	TEE_MemMove(params[0].memref.buffer, k1, TA_SEAL_KEY_LEN);
	params[0].memref.size = TA_SEAL_KEY_LEN;
	return TEE_SUCCESS;
}

static TEE_Result read_or_create_kek_bytes(uint8_t kek[TA_SEAL_KEY_LEN])
{
	TEE_Result res;
	TEE_ObjectHandle obj = TEE_HANDLE_NULL;
	uint32_t read_bytes = 0;
	uint32_t flags = TEE_DATA_FLAG_ACCESS_READ |
			 TEE_DATA_FLAG_ACCESS_WRITE |
			 TEE_DATA_FLAG_ACCESS_WRITE_META |
			 TEE_DATA_FLAG_SHARE_READ;

	res = TEE_OpenPersistentObject(TEE_STORAGE_PRIVATE,
				       kek_obj_id, sizeof(kek_obj_id) - 1,
				       flags, &obj);
	if (res == TEE_SUCCESS) {
		res = TEE_ReadObjectData(obj, kek, TA_SEAL_KEY_LEN, &read_bytes);
		TEE_CloseObject(obj);
		if (res != TEE_SUCCESS || read_bytes != TA_SEAL_KEY_LEN) {
			EMSG("kek read failed 0x%x", res);
			return (res != TEE_SUCCESS) ? res : TEE_ERROR_CORRUPT_OBJECT;
		}
		return TEE_SUCCESS;
	}
	if (res != TEE_ERROR_ITEM_NOT_FOUND) {
		EMSG("kek open failed 0x%x", res);
		return res;
	}

	TEE_GenerateRandom(kek, TA_SEAL_KEY_LEN);
	flags |= TEE_DATA_FLAG_OVERWRITE;
	res = TEE_CreatePersistentObject(TEE_STORAGE_PRIVATE,
					 kek_obj_id, sizeof(kek_obj_id) - 1,
					 flags, TEE_HANDLE_NULL,
					 kek, TA_SEAL_KEY_LEN, &obj);
	if (res != TEE_SUCCESS) {
		EMSG("kek create failed 0x%x", res);
		return res;
	}
	TEE_CloseObject(obj);
	return TEE_SUCCESS;
}

static TEE_Result store_kek_bytes(const uint8_t kek[TA_SEAL_KEY_LEN])
{
	TEE_Result res;
	TEE_ObjectHandle obj = TEE_HANDLE_NULL;
	uint32_t flags = TEE_DATA_FLAG_ACCESS_READ |
			 TEE_DATA_FLAG_ACCESS_WRITE |
			 TEE_DATA_FLAG_ACCESS_WRITE_META |
			 TEE_DATA_FLAG_SHARE_READ |
			 TEE_DATA_FLAG_OVERWRITE;

	res = TEE_CreatePersistentObject(TEE_STORAGE_PRIVATE,
					 kek_obj_id, sizeof(kek_obj_id) - 1,
					 flags, TEE_HANDLE_NULL,
					 kek, TA_SEAL_KEY_LEN, &obj);
	if (res != TEE_SUCCESS) {
		EMSG("kek store failed 0x%x", res);
		return res;
	}
	TEE_CloseObject(obj);
	return TEE_SUCCESS;
}

static TEE_Result wrap_key_object(TEE_ObjectHandle wrap_key,
				  const uint8_t *kek,
				  uint8_t *out, uint32_t *out_len)
{
	TEE_Result res;
	uint8_t nonce[TA_SEAL_NONCE_LEN];
	uint8_t tag[TA_SEAL_TAG_LEN];
	uint32_t tag_len = sizeof(tag);
	uint32_t ct_len = TA_SEAL_KEY_LEN;
	const uint8_t *aad = (const uint8_t *)TA_KEK_WRAP_AAD;

	if (*out_len < TA_KEK_WRAP_LEN)
		return TEE_ERROR_SHORT_BUFFER;

	TEE_GenerateRandom(nonce, sizeof(nonce));
	res = ae_crypt(TEE_MODE_ENCRYPT, wrap_key, nonce, sizeof(nonce),
		       aad, TA_KEK_WRAP_AAD_LEN, kek, TA_SEAL_KEY_LEN,
		       out + TA_KEK_WRAP_HDR_LEN, &ct_len, tag, &tag_len);
	if (res != TEE_SUCCESS || ct_len != TA_SEAL_KEY_LEN ||
	    tag_len != TA_SEAL_TAG_LEN)
		return (res != TEE_SUCCESS) ? res : TEE_ERROR_GENERIC;

	out[0] = TA_KEK_WRAP_MAGIC0;
	out[1] = TA_KEK_WRAP_MAGIC1;
	out[2] = TA_KEK_WRAP_MAGIC2;
	out[3] = TA_KEK_WRAP_MAGIC3;
	out[4] = TA_KEK_WRAP_VERSION;
	TEE_MemMove(out + 5, nonce, sizeof(nonce));
	TEE_MemMove(out + TA_KEK_WRAP_HDR_LEN + TA_SEAL_KEY_LEN, tag,
		    sizeof(tag));
	*out_len = TA_KEK_WRAP_LEN;
	return TEE_SUCCESS;
}

static TEE_Result unwrap_key_object(TEE_ObjectHandle wrap_key,
				    const uint8_t *in, uint32_t in_len,
				    uint8_t kek[TA_SEAL_KEY_LEN])
{
	TEE_Result res;
	uint8_t tag[TA_SEAL_TAG_LEN];
	uint32_t tag_len = sizeof(tag);
	uint32_t pt_len = TA_SEAL_KEY_LEN;
	const uint8_t *aad = (const uint8_t *)TA_KEK_WRAP_AAD;

	if (in_len != TA_KEK_WRAP_LEN)
		return TEE_ERROR_BAD_PARAMETERS;
	if (in[0] != TA_KEK_WRAP_MAGIC0 || in[1] != TA_KEK_WRAP_MAGIC1 ||
	    in[2] != TA_KEK_WRAP_MAGIC2 || in[3] != TA_KEK_WRAP_MAGIC3 ||
	    in[4] != TA_KEK_WRAP_VERSION)
		return TEE_ERROR_BAD_FORMAT;

	TEE_MemMove(tag, in + TA_KEK_WRAP_HDR_LEN + TA_SEAL_KEY_LEN,
		    sizeof(tag));
	res = ae_crypt(TEE_MODE_DECRYPT, wrap_key, in + 5, TA_SEAL_NONCE_LEN,
		       aad, TA_KEK_WRAP_AAD_LEN,
		       in + TA_KEK_WRAP_HDR_LEN, TA_SEAL_KEY_LEN,
		       kek, &pt_len, tag, &tag_len);
	if (res != TEE_SUCCESS || pt_len != TA_SEAL_KEY_LEN)
		return (res != TEE_SUCCESS) ? res : TEE_ERROR_MAC_INVALID;
	return TEE_SUCCESS;
}

static TEE_Result make_wrap_aes_key(TEE_ObjectHandle *key_out)
{
	TEE_Result res;
	TEE_ObjectHandle key = TEE_HANDLE_NULL;
	TEE_Attribute attr;
	uint8_t derived[TA_SEAL_KEY_LEN];

	res = derive_ta_unique_key(derived, sizeof(derived));
	if (res != TEE_SUCCESS)
		return res;

	res = TEE_AllocateTransientObject(TEE_TYPE_AES, TA_SEAL_KEY_LEN * 8,
					  &key);
	if (res != TEE_SUCCESS)
		return res;

	TEE_InitRefAttribute(&attr, TEE_ATTR_SECRET_VALUE, derived,
			     sizeof(derived));
	res = TEE_PopulateTransientObject(key, &attr, 1);
	TEE_MemFill(derived, 0, sizeof(derived));
	if (res != TEE_SUCCESS) {
		TEE_FreeTransientObject(key);
		return res;
	}
	*key_out = key;
	return TEE_SUCCESS;
}

static TEE_Result cmd_kek_export_wrap(uint32_t types, TEE_Param params[4])
{
	const uint32_t expect =
		TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_OUTPUT,
				TEE_PARAM_TYPE_NONE,
				TEE_PARAM_TYPE_NONE,
				TEE_PARAM_TYPE_NONE);
	TEE_Result res;
	TEE_ObjectHandle wrap_key = TEE_HANDLE_NULL;
	uint8_t kek[TA_SEAL_KEY_LEN];
	uint32_t out_len;

	if (types != expect)
		return TEE_ERROR_BAD_PARAMETERS;
	if (!params[0].memref.buffer)
		return TEE_ERROR_BAD_PARAMETERS;
	out_len = params[0].memref.size;
	if (out_len < TA_KEK_WRAP_LEN) {
		params[0].memref.size = TA_KEK_WRAP_LEN;
		return TEE_ERROR_SHORT_BUFFER;
	}

	res = read_or_create_kek_bytes(kek);
	if (res != TEE_SUCCESS)
		return res;
	res = make_wrap_aes_key(&wrap_key);
	if (res != TEE_SUCCESS)
		goto out;
	res = wrap_key_object(wrap_key, kek, params[0].memref.buffer, &out_len);
	if (res == TEE_SUCCESS)
		params[0].memref.size = out_len;

out:
	if (wrap_key != TEE_HANDLE_NULL)
		TEE_FreeTransientObject(wrap_key);
	TEE_MemFill(kek, 0, sizeof(kek));
	return res;
}

static TEE_Result cmd_kek_import_wrap(uint32_t types, TEE_Param params[4])
{
	const uint32_t expect =
		TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
				TEE_PARAM_TYPE_NONE,
				TEE_PARAM_TYPE_NONE,
				TEE_PARAM_TYPE_NONE);
	TEE_Result res;
	TEE_ObjectHandle wrap_key = TEE_HANDLE_NULL;
	uint8_t kek[TA_SEAL_KEY_LEN];

	if (types != expect)
		return TEE_ERROR_BAD_PARAMETERS;
	if (!params[0].memref.buffer)
		return TEE_ERROR_BAD_PARAMETERS;

	res = make_wrap_aes_key(&wrap_key);
	if (res != TEE_SUCCESS)
		return res;
	res = unwrap_key_object(wrap_key, params[0].memref.buffer,
				params[0].memref.size, kek);
	TEE_FreeTransientObject(wrap_key);
	if (res != TEE_SUCCESS)
		return res;
	res = store_kek_bytes(kek);
	TEE_MemFill(kek, 0, sizeof(kek));
	return res;
}

static TEE_Result cmd_seal(uint32_t types, TEE_Param params[4])
{
	const uint32_t expect =
		TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
				TEE_PARAM_TYPE_MEMREF_INPUT,
				TEE_PARAM_TYPE_MEMREF_OUTPUT,
				TEE_PARAM_TYPE_NONE);
	TEE_Result res;
	TEE_ObjectHandle key = TEE_HANDLE_NULL;
	uint8_t *plain;
	size_t plain_len;
	uint8_t *aad;
	size_t aad_len;
	uint8_t *out;
	size_t out_cap;
	uint8_t nonce[TA_SEAL_NONCE_LEN];
	uint8_t tag[TA_SEAL_TAG_LEN];
	uint32_t tag_len = sizeof(tag);
	uint32_t ct_len;
	size_t need;

	if (types != expect)
		return TEE_ERROR_BAD_PARAMETERS;

	plain = params[0].memref.buffer;
	plain_len = params[0].memref.size;
	aad = params[1].memref.buffer;
	aad_len = params[1].memref.size;
	out = params[2].memref.buffer;
	out_cap = params[2].memref.size;

	if (!plain || !plain_len || plain_len > TA_SEAL_MAX_PLAIN)
		return TEE_ERROR_BAD_PARAMETERS;
	if (aad_len && !aad)
		return TEE_ERROR_BAD_PARAMETERS;

	need = TA_SEAL_HDR_LEN + plain_len + TA_SEAL_TAG_LEN;
	if (out_cap < need) {
		params[2].memref.size = need;
		return TEE_ERROR_SHORT_BUFFER;
	}
	if (!out)
		return TEE_ERROR_BAD_PARAMETERS;

	res = load_or_create_kek(&key);
	if (res != TEE_SUCCESS)
		return res;

	TEE_GenerateRandom(nonce, sizeof(nonce));
	ct_len = (uint32_t)plain_len;
	res = ae_crypt(TEE_MODE_ENCRYPT, key,
		       nonce, sizeof(nonce),
		       aad, (uint32_t)aad_len,
		       plain, (uint32_t)plain_len,
		       out + TA_SEAL_HDR_LEN, &ct_len,
		       tag, &tag_len);
	TEE_FreeTransientObject(key);
	if (res != TEE_SUCCESS) {
		EMSG("seal ae failed 0x%x", res);
		return res;
	}
	if (ct_len != plain_len || tag_len != TA_SEAL_TAG_LEN)
		return TEE_ERROR_GENERIC;

	out[0] = TA_SEAL_BLOB_MAGIC0;
	out[1] = TA_SEAL_BLOB_MAGIC1;
	out[2] = TA_SEAL_BLOB_MAGIC2;
	out[3] = TA_SEAL_BLOB_MAGIC3;
	out[4] = TA_SEAL_BLOB_VERSION;
	TEE_MemMove(out + 5, nonce, sizeof(nonce));
	TEE_MemMove(out + TA_SEAL_HDR_LEN + ct_len, tag, TA_SEAL_TAG_LEN);
	params[2].memref.size = TA_SEAL_HDR_LEN + ct_len + TA_SEAL_TAG_LEN;
	return TEE_SUCCESS;
}

static TEE_Result cmd_unseal(uint32_t types, TEE_Param params[4])
{
	const uint32_t expect =
		TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
				TEE_PARAM_TYPE_MEMREF_INPUT,
				TEE_PARAM_TYPE_MEMREF_OUTPUT,
				TEE_PARAM_TYPE_NONE);
	TEE_Result res;
	TEE_ObjectHandle key = TEE_HANDLE_NULL;
	uint8_t *blob;
	size_t blob_len;
	uint8_t *aad;
	size_t aad_len;
	uint8_t *out;
	size_t out_cap;
	uint8_t *nonce;
	uint8_t *ct;
	uint8_t *tag;
	size_t ct_len;
	size_t plain_len;

	if (types != expect)
		return TEE_ERROR_BAD_PARAMETERS;

	blob = params[0].memref.buffer;
	blob_len = params[0].memref.size;
	aad = params[1].memref.buffer;
	aad_len = params[1].memref.size;
	out = params[2].memref.buffer;
	out_cap = params[2].memref.size;

	if (!blob || blob_len < TA_SEAL_HDR_LEN + TA_SEAL_TAG_LEN)
		return TEE_ERROR_BAD_PARAMETERS;
	if (aad_len && !aad)
		return TEE_ERROR_BAD_PARAMETERS;
	if (blob[0] != TA_SEAL_BLOB_MAGIC0 || blob[1] != TA_SEAL_BLOB_MAGIC1 ||
	    blob[2] != TA_SEAL_BLOB_MAGIC2 || blob[3] != TA_SEAL_BLOB_MAGIC3 ||
	    blob[4] != TA_SEAL_BLOB_VERSION)
		return TEE_ERROR_BAD_FORMAT;

	nonce = blob + 5;
	ct = blob + TA_SEAL_HDR_LEN;
	ct_len = blob_len - TA_SEAL_HDR_LEN - TA_SEAL_TAG_LEN;
	tag = blob + TA_SEAL_HDR_LEN + ct_len;

	if (ct_len == 0 || ct_len > TA_SEAL_MAX_PLAIN)
		return TEE_ERROR_BAD_PARAMETERS;
	if (out_cap < ct_len) {
		params[2].memref.size = ct_len;
		return TEE_ERROR_SHORT_BUFFER;
	}
	if (!out)
		return TEE_ERROR_BAD_PARAMETERS;

	res = load_or_create_kek(&key);
	if (res != TEE_SUCCESS)
		return res;

	plain_len = ct_len;
	{
		uint8_t nonce_local[TA_SEAL_NONCE_LEN];
		uint8_t tag_local[TA_SEAL_TAG_LEN];
		uint32_t tag_len = TA_SEAL_TAG_LEN;
		uint32_t out_len = (uint32_t)plain_len;

		/* Copy out of the INPUT memref — some Rockchip BL32 builds
		 * panic (TARGET_DEAD) if AEDecryptFinal's tag points at it. */
		TEE_MemMove(nonce_local, nonce, sizeof(nonce_local));
		TEE_MemMove(tag_local, tag, sizeof(tag_local));

		res = ae_crypt(TEE_MODE_DECRYPT, key,
			       nonce_local, TA_SEAL_NONCE_LEN,
			       aad, (uint32_t)aad_len,
			       ct, (uint32_t)ct_len,
			       out, &out_len,
			       tag_local, &tag_len);
		plain_len = out_len;
	}
	TEE_FreeTransientObject(key);
	if (res != TEE_SUCCESS) {
		/* Wrong AAD / corrupt blob — fail closed, no plaintext. */
		EMSG("unseal ae failed 0x%x", res);
		return res;
	}
	params[2].memref.size = plain_len;
	return TEE_SUCCESS;
}

TEE_Result TA_CreateEntryPoint(void)
{
	return TEE_SUCCESS;
}

void TA_DestroyEntryPoint(void)
{
}

TEE_Result TA_OpenSessionEntryPoint(uint32_t types,
				    TEE_Param params[4],
				    void **sess_ctx)
{
	(void)params;
	(void)sess_ctx;
	if (types != TEE_PARAM_TYPES(TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE,
				     TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE))
		return TEE_ERROR_BAD_PARAMETERS;
	return TEE_SUCCESS;
}

void TA_CloseSessionEntryPoint(void *sess_ctx)
{
	(void)sess_ctx;
}

TEE_Result TA_InvokeCommandEntryPoint(void *sess_ctx,
				      uint32_t cmd,
				      uint32_t types,
				      TEE_Param params[4])
{
	(void)sess_ctx;
	switch (cmd) {
	case TA_SEAL_CMD_PROBE:
		return cmd_probe(types, params);
	case TA_SEAL_CMD_SEAL:
		return cmd_seal(types, params);
	case TA_SEAL_CMD_UNSEAL:
		return cmd_unseal(types, params);
	case TA_SEAL_CMD_DERIVE_PROBE:
		return cmd_derive_probe(types, params);
	case TA_SEAL_CMD_KEK_EXPORT_WRAP:
		return cmd_kek_export_wrap(types, params);
	case TA_SEAL_CMD_KEK_IMPORT_WRAP:
		return cmd_kek_import_wrap(types, params);
	default:
		return TEE_ERROR_NOT_SUPPORTED;
	}
}
