/// Modbus control-board firmware upgrade constants (lws-ui DeviceUpgradeConstant).
abstract final class FirmwareUpgradeConstants {
  static const int firmwareInfo = 0x1234;
  static const int firmwareData = 0x55AA;
  static const int firmwareEnd = 0x0000;

  /// Max payload bytes per data packet (64 holding words).
  static const int packetMaxBytes = 128;

  /// Words in `upgrade.data` attribute.
  static const int dataWindowWords = 64;

  /// Overall wait before first packet progress.
  static const Duration upgradeTimeout = Duration(minutes: 1);

  /// No packet progress for this long → stall failure.
  static const Duration stallTimeout = Duration(seconds: 30);

  static const String upgradeGroup = 'upgrade';
  static const String attrHw = 'upgrade.fw_hw_version';
  static const String attrSw = 'upgrade.fw_sw_version';
  static const String attrSizeHigh = 'upgrade.fw_size_high';
  static const String attrSizeLow = 'upgrade.fw_size_low';
  static const String attrCheckHigh = 'upgrade.fw_check_high';
  static const String attrCheckLow = 'upgrade.fw_check_low';
  static const String attrOffsetHigh = 'upgrade.fw_offset_high';
  static const String attrOffsetLow = 'upgrade.fw_offset_low';
  static const String attrByteCount = 'upgrade.fw_byte_count';
  static const String attrCommand = 'upgrade.fw_command';
  static const String attrPacketCrcHigh = 'upgrade.packet_crc_high';
  static const String attrPacketCrcLow = 'upgrade.packet_crc_low';
  static const String attrData = 'upgrade.data';

  static const String deviceHw = 'device.control_hw_version';
  static const String deviceSw = 'device.control_card_version';
}
