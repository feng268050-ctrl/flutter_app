import 'dart:convert';
import 'dart:io';

/// Starts a subprocess (injectable for tests).
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool includeParentEnvironment,
  bool runInShell,
});

/// Thin wrapper around [Process.start] / exit handling.
final class ProcessRunner {
  ProcessRunner({ProcessStarter? startProcess})
      : _startProcess = startProcess ?? Process.start;

  final ProcessStarter _startProcess;

  Future<Process> start(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
  }) {
    return _startProcess(
      executable,
      arguments,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: false,
    );
  }

  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
  }) async {
    final process = await start(
      executable,
      arguments,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
    );
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    return ProcessResult(
      process.pid,
      code,
      await stdoutFuture,
      await stderrFuture,
    );
  }

  Future<void> runChecked(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? errorPrefix,
  }) async {
    final result = await run(
      executable,
      arguments,
      environment: environment,
    );
    if (result.exitCode != 0) {
      final detail = '${result.stderr}'.trim();
      final prefix = errorPrefix ?? executable;
      throw StateError(
        detail.isEmpty
            ? '$prefix failed (exit ${result.exitCode})'
            : '$prefix failed (exit ${result.exitCode}): $detail',
      );
    }
  }
}
