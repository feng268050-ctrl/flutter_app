## 1. Version script

- [x] 1.1 Add `scripts/make/app-version.sh` with `print` (read `versionName` + `versionCode` from `app/build.gradle.kts`, emit `name+code`) and `bump` (validate `VERSION`, rewrite Gradle)
- [x] 1.2 Implement validation: major/minor single digit `0`–`9`, patch `0`–`100`, build positive integer after `+`; clear stderr messages on failure
- [x] 1.3 After bump, re-read and print new combined version; exit non-zero if post-write parse fails

## 2. Gradle source of truth

- [x] 2.1 Change `app/build.gradle.kts` to use literal `versionCode = <n>` (remove `getGitCount()` usage for app version)
- [x] 2.2 Remove `getGitCount()` if unused elsewhere in the file

## 3. Makefile integration

- [x] 3.1 Add `.PHONY` targets `version` and `version-bump` delegating to `scripts/make/app-version.sh`
- [x] 3.2 Extend `make help` with a Version section (`make version`, `make version-bump VERSION=1.0.8+108`)

## 4. Verification

- [x] 4.1 Run `make version` and confirm output matches `app/build.gradle.kts`
- [x] 4.2 Run `make version-bump VERSION=1.0.27+<build>` (or next release) and confirm Gradle + `make version` agree
- [x] 4.3 Confirm invalid inputs (`10.0.0+1`, `1.0.101+1`, missing `VERSION`) exit non-zero
