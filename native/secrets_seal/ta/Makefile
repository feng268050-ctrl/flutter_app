# The UUID for the Trusted Application (must match seal_ta.h)
BINARY=b8e4f2a1-9c3d-4e6f-8a1b-2c3d4e5f6071

CFG_TEE_TA_LOG_LEVEL ?= 2

-include $(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk

ifeq ($(wildcard $(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk),)
clean:
	@echo 'Note: $$(TA_DEV_KIT_DIR)/mk/ta_dev_kit.mk not found, cannot clean TA'
	@echo 'Note: TA_DEV_KIT_DIR=$(TA_DEV_KIT_DIR)'
endif
