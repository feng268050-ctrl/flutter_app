## 1. Locate and normalize jump/edit prefill source

- [x] 1.1 Identify the exact Continuous Weld and Spot Weld jump action handlers that open the process-name edit dialog.
- [x] 1.2 Trace the current default prefill value source (stored name vs material-derived default) and document the shared code path.

## 2. Implement locale-correct default name behavior

- [x] 2.1 Extend/reuse the material-name localization utility to normalize known built-in Chinese material labels to active-locale labels for dialog prefill.
- [x] 2.2 Apply the localization step in the jump/edit prefill path so English locale always shows English defaults for known built-in labels.
- [x] 2.3 Ensure custom user-defined process names bypass forced translation and are preserved exactly.

## 3. Verify behavior in both locales

- [x] 3.1 Validate English locale: Continuous Weld and Spot Weld jump/edit dialogs prefill in English, including known legacy Chinese stored labels.
- [x] 3.2 Validate Chinese locale: existing Chinese display remains correct and unchanged.
- [x] 3.3 Regression-check material selector/current material rendering remains locale-correct and process IDs/storage semantics remain unchanged.
