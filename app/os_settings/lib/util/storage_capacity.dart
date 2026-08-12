/// Re-export HAL storage capacity helpers (prefer `package:cyber_hal/sys_info.dart`).
library;

export 'package:cyber_hal/sys_info.dart'
    show
        StorageBarColors,
        StorageBarSegment,
        StorageCapacitySummary,
        StorageInfo,
        formatStorageBytes,
        kStorageUnavailableDash,
        storageMountColor,
        storageSummaryLine,
        summarizeStorage;
