/// Default on-device OTA staging directory (`LWS_HMI_OTA_DIR` on board helpers).
const kDefaultStagingDir = '/userdata/ota/';

const kPackageFileName = 'ota-package.tar.gz';
const kSigFileName = 'ota-package.tar.gz.sig';
const kApplyStatusFileName = 'apply.status';
const kOtaLogFileName = 'ota.log';

const kBootImgFileName = 'boot.img';
const kBootBImgFileName = 'boot_b.img';
const kRootfsImgFileName = 'rootfs.img';
const kOemImgFileName = 'oem.img';

/// Ed25519 pubkey embedded in rootfs (matches host `ota-sign.sh`).
const kDefaultOtaPubkey = '/etc/ota/ed25519.pub';

/// misc A/B marker offset — keep clear of vendor boot-control @ 0x0800.
const kAbMiscOffset = 1048576;
const kAbDefaultTries = 3;

/// `dd` block size for partition image writes.
const kDdBlockSize = 4 * 1024 * 1024;

const kOtaModeCloud = 'cloud';
const kOtaModeHost = 'host';
const kOtaModeOem = 'oem';
