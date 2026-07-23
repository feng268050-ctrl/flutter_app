## 1. 文档与设计对齐

- [x] 1.1 修订 `docs/ime-font-design.md`（枚举名、WiFi、dimen 绑定、EditText 路径、frosted glass 非目标、OpenSpec 交叉引用）
- [x] 1.2 在 `docs/ime-field-type-keyboard-design.md` 增加字体方案交叉引用

## 2. 字体资源接入（Phase 1）

- [x] 2.1 从 rsms/inter、JetBrains/JetBrainsMono 官方仓库获取 TTF 并重命名为 `inter_*.ttf` / `jetbrains_mono_*.ttf`
- [x] 2.2 添加 `assets/licenses/fonts/INTER_OFL.txt` 与 `JETBRAINS_MONO_OFL.txt`
- [x] 2.3 创建 `ImeFontFamilies.kt`（Inter + Mono 单例 FontFamily）
- [x] 2.4 编译验证 `:app:compileDebugKotlin` 资源可用

## 3. Typography 与 Resolver（Phase 1–2）

- [x] 3.1 创建 `ImeTypography.kt`：KeyLabel / KeyHint / KeyPopup / ActionKeyLabel / AccentKeyLabel / TextInputValue / MonoInputValue，字号来自 `ime_dimens.xml`
- [x] 3.2 创建 `ImeFontResolver.kt`：`inputTextStyleFor(type, passwordVisible)` + 键帽 style 访问器
- [x] 3.3 添加 `ImeFontResolverTest`：Field Type 映射与 Password visible/hidden 分支

## 4. 键帽字体（Phase 2）— 不改 frosted glass

- [x] 4.1 `ImeKeyCap`：字母/符号/默认键 `Text` 改用 `ImeTypography.KeyLabel`
- [x] 4.2 `ImeKeyCap`：secondary hint 改用 `KeyHint`；`ImeAlternatePopup` 改用 `KeyPopup`
- [x] 4.3 `ImeSingleAccentKeyShell` 内容：⌫/C/− 等改用 `AccentKeyLabel`（仅 TextStyle，不改 shell glass）
- [x] 4.4 `ImeEnterKey`：文字 Enter 配置用 `ActionKeyLabel`；默认图标 Enter 保持 vector，不套文字 style
- [x] 4.5 确认 **未修改** `ImeGlassKeyBackground`、`ImePrimaryKeyShell` fill/border/ripple 参数（除非修复无关 bug）
- [x] 4.6 Emulator 目视：QWERTY / 123 / 符号层 / 数字盘键帽 glass 与间距无回归

## 5. 输入框字体（Phase 3）

- [x] 5.1 新增 `ImeFontTypeface`（或 resolver 扩展）：`applyTo(EditText, fieldType, passwordVisible)`
- [x] 5.2 `FrostedGlassTextInputDialog` → Inter（Text）
- [x] 5.3 `FrostedGlassNumericInputDialog` → Mono（Number / SignedDecimal）
- [x] 5.4 `FrostedGlassWifiPasswordDialog` → 掩码/明文切换 Mono
- [x] 5.5 Password 显示切换回调中重新 apply Typeface

## 6. 验收与收尾（Phase 4）

- [x] 6.1 运行 `:app:testDebugUnitTest --tests "com.lasercyber.lws.ime.*"`
- [x] 6.2 Emulator 联调：Text / Numeric / WiFi 弹窗 + 键盘同时可见，字体一致、glass 不变
- [x] 6.3 检查 APK 体积增量并记录于 `docs/ime-font-design.md` §16
- [x] 6.4 `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`
