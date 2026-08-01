/* SPDX-License-Identifier: BSD-2-Clause */
#include <tee_internal_api.h>
#include <tee_internal_api_extensions.h>

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
		uint32_t tag_len = TA_SEAL_TAG_LEN;
		uint32_t out_len = (uint32_t)plain_len;

		res = ae_crypt(TEE_MODE_DECRYPT, key,
			       nonce, TA_SEAL_NONCE_LEN,
			       aad, (uint32_t)aad_len,
			       ct, (uint32_t)ct_len,
			       out, &out_len,
			       tag, &tag_len);
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
	default:
		return TEE_ERROR_NOT_SUPPORTED;
	}
}
