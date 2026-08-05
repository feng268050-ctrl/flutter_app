import 'ota_progress.dart';

/// Ingress adapter selecting verify gate and transfer semantics.
sealed class OtaIngress {
  const OtaIngress();

  OtaIngressKind get kind;

  /// Whether Ed25519 verification is required before extract/apply.
  bool get requireVerify;
}

/// Cloud download of `tar.gz` + `.sig`; verify is mandatory.
final class CloudIngress extends OtaIngress {
  const CloudIngress();

  @override
  OtaIngressKind get kind => OtaIngressKind.cloud;

  @override
  bool get requireVerify => true;
}

/// Host `make upgrade` HTTP pull from the ephemeral host server; verify mandatory.
final class HostHttpIngress extends OtaIngress {
  const HostHttpIngress();

  @override
  OtaIngressKind get kind => OtaIngressKind.host;

  @override
  bool get requireVerify => true;
}

/// Local/testing staging; defaults to requiring verify (SSH/host parity).
final class LocalStagingIngress extends OtaIngress {
  const LocalStagingIngress({this.requireVerify = true});

  @override
  OtaIngressKind get kind => OtaIngressKind.local;

  @override
  final bool requireVerify;
}
