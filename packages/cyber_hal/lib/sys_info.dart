/// Host inventory + telemetry (`sys_info` HAL module).
///
/// Separate classes under one module (not one mega-type):
/// - [SysInfo] / [SysInfoSnapshot] — live identity + volatile host metrics
/// - [LinuxPlatformVersions] / [PlatformVersionsSnapshot] — OS/stack version inventory
/// - [StorageInfo] + [summarizeStorage] / [StorageCapacitySummary] — capacity bar
/// - [ProductInfo] — factory identity (Vendor Storage)
/// - Helpers: [formatOperatingSystemLabel], [formatOperatingSystemName], …
library;

export 'package:cyber_hal/src/sys_info/platform_versions.dart';
export 'package:cyber_hal/src/sys_info/sys_info.dart';
