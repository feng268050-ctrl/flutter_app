/// When true, coordinator must not call [WarnPresentation.show].
abstract interface class WarnGate {
  bool get isPresentationSuppressed;
}

/// Always allows presentation.
final class AllowWarnGate implements WarnGate {
  const AllowWarnGate();

  @override
  bool get isPresentationSuppressed => false;
}

/// Fixed gate for tests.
final class FixedWarnGate implements WarnGate {
  const FixedWarnGate({required this.isPresentationSuppressed});

  @override
  final bool isPresentationSuppressed;
}
