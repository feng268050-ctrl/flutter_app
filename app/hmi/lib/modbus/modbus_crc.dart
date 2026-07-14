/// Modbus RTU CRC-16 (poly 0xA001).
int modbusCrc16(List<int> data) {
  var crc = 0xFFFF;
  for (final b in data) {
    crc ^= b & 0xFF;
    for (var i = 0; i < 8; i++) {
      if ((crc & 0x0001) != 0) {
        crc = (crc >> 1) ^ 0xA001;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc & 0xFFFF;
}

List<int> appendModbusCrc(List<int> pdu) {
  final crc = modbusCrc16(pdu);
  return <int>[...pdu, crc & 0xFF, (crc >> 8) & 0xFF];
}

bool verifyModbusCrc(List<int> frame) {
  if (frame.length < 4) {
    return false;
  }
  final without = frame.sublist(0, frame.length - 2);
  final expected = modbusCrc16(without);
  final got = frame[frame.length - 2] | (frame[frame.length - 1] << 8);
  return expected == got;
}
