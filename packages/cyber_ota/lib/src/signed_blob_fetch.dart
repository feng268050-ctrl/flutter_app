import 'dart:io';

import 'http_client.dart';
import 'ota_constants.dart';
import 'ota_verify.dart';

/// Download a signed blob (`url` + sibling `url.sig`) and Ed25519-verify it.
///
/// Used by peripheral firmware (control-board / camera) host HTTP and cloud
/// paths. Does **not** extract or apply — callers own Modbus / CGI apply.
final class SignedBlobFetch {
  SignedBlobFetch({
    OtaHttpClient? httpClient,
    OtaVerify? verify,
  })  : _http = httpClient ?? HttpOtaClient(),
        _verify = verify ?? OtaVerify();

  final OtaHttpClient _http;
  final OtaVerify _verify;

  /// Downloads [packageUrl] into `[stagingDir]/[fileName]` and
  /// `[packageUrl].sig` (or [sigUrl]) into `[stagingDir]/[fileName].sig`,
  /// then verifies. Returns the verified package [File].
  Future<File> downloadAndVerify({
    required String packageUrl,
    required String stagingDir,
    required String fileName,
    String? sigUrl,
    void Function(int bytesReceived, int? bytesTotal)? onProgress,
  }) async {
    final dir = stagingDir.endsWith('/') ? stagingDir : '$stagingDir/';
    final packagePath = '$dir$fileName';
    final sigPath = '$packagePath.sig';
    final resolvedSigUrl = sigUrl ?? '$packageUrl.sig';

    await Directory(dir).create(recursive: true);
    await _http.download(packageUrl, packagePath, onProgress: onProgress);
    await _http.download(resolvedSigUrl, sigPath);
    await _verify.verifyPackage(archivePath: packagePath, sigPath: sigPath);
    return File(packagePath);
  }
}

/// Staging dirs for peripheral signed downloads (under [kDefaultStagingDir]).
const kControlBoardStagingDir = '${kDefaultStagingDir}control-board/';
const kCameraStagingDir = '${kDefaultStagingDir}camera/';
