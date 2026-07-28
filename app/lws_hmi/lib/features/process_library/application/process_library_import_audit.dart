import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

enum ProcessLibraryImportStatus {
  imported,
  current,
  noCompatibleLibrary,
  rejected,
}

final class ProcessLibraryImportResult {
  const ProcessLibraryImportResult(this.status, {this.meta});

  final ProcessLibraryImportStatus status;
  final ProcessLibraryMeta? meta;
}

/// Structured result for offline / OTA / bundled process-library imports.
final class ProcessLibraryImportAudit {
  const ProcessLibraryImportAudit({
    required this.status,
    this.packagePath,
    this.source,
    this.fromVersion,
    this.toVersion,
    this.contentSha256,
    this.rowCount,
    this.modelMatched = false,
    this.preservedUserCount = 0,
    this.skippedReason,
    this.errors = const [],
    this.meta,
  });

  final ProcessLibraryImportStatus status;
  final String? packagePath;
  final String? source;
  final String? fromVersion;
  final String? toVersion;
  final String? contentSha256;
  final int? rowCount;
  final bool modelMatched;
  final int preservedUserCount;
  final String? skippedReason;
  final List<String> errors;
  final ProcessLibraryMeta? meta;

  bool get isSuccess =>
      status == ProcessLibraryImportStatus.imported ||
      status == ProcessLibraryImportStatus.current;

  ProcessLibraryImportResult toResult() =>
      ProcessLibraryImportResult(status, meta: meta);
}
