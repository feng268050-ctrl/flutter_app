## 1. Cluster reducer (pure Java)

- [x] 1.1 Add `ZeroPointDetectClusterReducer` with `CLUSTER_TOLERANCE_PX=3`, `ROUND_ANCHOR_MAX_DEVIATION_PX=10`, input `Observation(offsetX, offsetY, arrivalIndex)`, output `Result` (representative offsets, clusterCount, winnerClusterSize, anchorRejectedCount)
- [x] 1.2 Implement union-find clustering on axis-aligned 3px tolerance and winner selection (max count → lexicographic mean tie-break)
- [x] 1.3 Implement representative pick (nearest Euclidean to cluster centroid → earliest index tie-break)
- [x] 1.4 Implement anchor pre-filter and rule-1-priority merge (full-sample cluster wins when strictly larger than anchor-filtered winner)
- [x] 1.5 Add unit tests: single cluster, multi-cluster winner, centroid nearest, anchor 10px reject, rule-1 overrides anchor, empty input, tie-break cases

## 2. Integrate ZeroPointDetectCoordinator

- [x] 2.1 Replace arithmetic mean in `finalizeTaskLocked` with reducer on `validOffsetX`/`validOffsetY` paired list (preserve arrival order)
- [x] 2.2 Log reducer metadata (`clusterCount`, `winnerClusterSize`, `anchorRejected`, representative offsets) under `ZeroPointDetect` or dedicated TAG
- [x] 2.3 Update or add coordinator tests if present; verify `validSamples` logging reflects reducer outcome

## 3. Integrate ZeroPointManualAutoCoordinator

- [x] 3.1 Replace `StageAggregate.from(List<Double>, List<Double>)` mean logic with reducer per stage list (`online_500ms`, `offline_200ms`, `offline_100ms`)
- [x] 3.2 Ensure online sample append order matches arrival index for reducer input
- [x] 3.3 Add/adjust unit tests for `StageAggregate` / reducer wiring with multi-sample fixtures

## 4. Verification

- [x] 4.1 Run `./gradlew :app:testDebugUnitTest --tests '*ZeroPointDetectCluster*'` (and Manual Auto related tests)
- [x] 4.2 Document logcat tags in `docs/OPENCV_DETECT_APP_INTEGRATION.md` acceptance section (optional one-line if already covered)
- [ ] 4.3 Device smoke: one Auto run — confirm `clusterWinnerSize` / representative offset in logcat when multiple online samples exist
