# IME 字段类型与键盘规划

本文档规划 **按输入字段类型（Field Type）弹出不同自定义键盘** 的方案，用于在现有 `com.lasercyber.lws.ime` 架构上扩展 Decimal、Email、Uri、Password 等类型，并支持未来新增类型。

**相关文档**：

- `docs/ime-compose-refactor-design.md` — IME 包结构、`ImeController`、overlay 抬升
- `docs/IME.md` — overlay 触摸、backdrop、slot 宿主排查
- `docs/ime-font-design.md` — Inter + JetBrains Mono 字体方案（键帽 / 输入框，**不改 frosted glass**）
- `.cursor/rules/ime-keyboard-baseline.mdc` — 键盘 A（全局 QWERTY + 123）/ 键盘 B（专用数字）产品基线

**现状入口**（已实现）：

- `ImeOverlaySpec.create(config, fieldType, onEditorAction, numericPolicyOverride?)`（`numericInput` 已 deprecated）
- `KeyboardController.forFieldType(...)` ← `ImeFieldProfileRegistry.profile(fieldType)`
- 已接入：`FrostedGlassTextInputDialog`→`Text`；`FrostedGlassNumericInputDialog`→`Number`/`SignedDecimal`；`FrostedGlassWifiPasswordDialog`→`WiFi`
- Registry 已定义、Dialog **未接**：`Email` / `Uri` / `Password`（见 §8 Phase 5）

### 实现进度（2026-06）

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 1–3 IME 内核 | **已完成** | Field Type、Registry、符号层、NumericPolicy、BottomRowProfile |
| Phase 4 文档治理 | **进行中** | 本文档 + baseline rule 同步 |
| Phase 5 场景接入 | **未开始** | Email/Uri/Password 等 Dialog 改 `fieldType` |

**策略**：**先完成 IME 内核，业务场景按需接入** — 新场景仅改 `ImeOverlaySpec.fieldType`，不动 overlay 管线。

---

## 1. 背景与目标

### 1.1 要支持的字段类型


| 类型 | 设计状态 | 说明 |
|------|----------|------|
| **Text** | ✅ 已接入 | 键盘 A；`FrostedGlassTextInputDialog` |
| **Number** | ✅ 已接入 | 键盘 B + `NumericPolicy` 整数 |
| **SignedDecimal** | ✅ 已接入 | 键盘 B + signed/decimal config；Numeric Dialog |
| **Email** | ✅ Registry | QWERTY + Email 底行 Profile；**Dialog 待接** |
| **Uri** | ✅ Registry | QWERTY + Uri 底行 Profile；**Dialog 待接** |
| **Password** | ✅ Registry | QWERTY + 👁 + 掩码；**Dialog 待接** |
| **WiFi** | ✅ 已接入 | 独立 Profile；`FrostedGlassWifiPasswordDialog` |


后续可能新增 Phone、Hex、Pin 等 — **不应** 为每种类型复制一套 overlay attach 逻辑。

### 1.2 目标

1. **单一入口**：业务侧声明 `ImeFieldType`，由注册表决定初始键盘、可切换布局、Enter 键与输入策略。
2. **布局复用**：Field Type 与 Keyboard Layout **不必 1:1**；Email / Uri 仅改 **底行 Profile**，不 rush 独立整盘 Layout。
3. **Policy 收敛**：Number / SignedDecimal / Stepper 共用 **`NumericPolicy`**（配置项区分整数、符号、小数），避免 Policy 类型爆炸。
4. **行为与 UI 分离**：Password / WiFi 各用独立 Profile；掩码、显示/隐藏等与 Layout 解耦。
5. **样式按按键角色**：Single 橙框功能键、Shift 三态等 **不按 Field Type 分叉**（见 `KeyDef.usesSingleAccentKeycap`）。
6. **扩展成本低**：新增类型 = 枚举 + Registry 条目 +（可选）底行 Profile / Policy 配置 + 测试。
7. **主动作键唯一**：各层右下 **仅一个** 主动作键，标签/图标由 **`ImeEnterKeyConfig`** 决定；统一用 **⏎**（取消 SEND + 纸飞机）。

### 1.3 非目标

- 首版不注册 Android 系统 `InputMethodService`。
- 不在 `ime` 包内实现业务校验（Modbus 范围、工艺参数名规则等仍留在 `ui`）。
- 不为一类字段单独改 `FrostOverlayHost` / touch / backdrop 管线（除非新布局行高不同）。

---

## 2. 现有键盘资产（产品基线）

### 2.1 键盘 A — 全局 QWERTY + 123 / 符号

- **Kind**：`KeyboardKind.EnglishGlobal` / `ChineseGlobal` + 符号层（123 切换）
- **布局**：`GlobalQwertyLayout` + `GlobalSymbolsPrimaryLayout` + `GlobalSymbolsExtendedLayout`
- **场景**：文本弹窗、WiFi 密码、Process Parameter Name 等
- **与旧版差异**：123 不再是 4×4 电话盘；改为主符号层 + `#+=` 扩展符号层（iOS 风格分层）。

#### 2.1.0 QWERTY 底行（Text 默认）

```
123  [space — 加宽]  .  ⏎
```

- **`.`** 为主键，`,` 为 long-press / 弹窗次选（二者位置已互换，相对早期 `@` + `,/.` 设计）。
- **无 `@`**；Email Profile 底行仍保留 `@` / `.com`。

#### 2.1.1 主符号层（123 切换进入，iOS 图二）

QWERTY 行末 **123** → 进入本层；本层 **ABC** → 返回 QWERTY。

```
1  2  3  4  5  6  7  8  9  0
-  /  :  ;  (  )  $  &  @  "
#+=  ,  .  ?  !  '  ⌫
ABC  [space]  ⏎
```

| 键 | 角色 |
|----|------|
| `1`–`0` | 数字直输 |
| 第二行 | `- / : ; ( ) $ & @ "` 直输 |
| `#+=` | **层切换** → 扩展符号层（§2.1.2） |
| `,` `.` | 标点（`,` 在 `.` 左侧） |
| `?` `!` `'` | 标点直输 |
| `⌫` | 退格（Single 功能键样式） |
| `ABC` | **层切换** → QWERTY |
| `[space]` | 空格 |
| `⏎` | **唯一主动作键**（`ImeEnterKeyConfig`） |

#### 2.1.2 扩展符号层（`#+=` 进入，iOS 图三）

```
[  ]  {  }  #  %  ^  *  +  =
_  \  |  ~  <  >  €  £  ¥  •
123  ,  .  ?  !  '  ⌫
ABC  [space]  ⏎
```

| 键 | 角色 |
|----|------|
| 第一、二行 | 扩展符号直输 |
| `123` | **层切换** → 主符号层 |
| `ABC` | **层切换** → QWERTY |
| `⌫` | 退格（Single 功能键样式） |
| `⏎` | **唯一主动作键** |

#### 2.1.3 层切换关系

```
                    123
    QwertyGlobal ◄────────► SymbolsPrimaryA
         ▲    ABC              │  #+=
         │                     ▼
         │              SymbolsExtendedA
         │                     │ 123
         └──── ABC ────────────┘
```

- **QWERTY ↔ 主符号层**：`123` / `ABC`
- **主符号层 ↔ 扩展符号层**：`#+=` 进入；扩展层 **`123`** 返回主符号层
- **扩展层 → QWERTY**：`ABC`

> **实现备注**：`KeyboardKind.NumericGlobal` 可保留枚举名，语义改为「全局符号层族」；内部分 `primary` / `extended` 子态，或由 `KeyboardLayoutId` 驱动行列，避免为每层新增独立 Kind。

### 2.2 键盘 B — 专用数字

- **Kind**：`KeyboardKind.NumericDedicated`
- **布局**：`DedicatedNumericLayout`
- **场景**：`FrostedGlassNumericInputDialog`（`fieldType = Number` / `SignedDecimal`）
- **布局**：
  ```
  1  2  3  ⌫
  4  5  6  C
  7  8  9  -
  .  0  00  ⏎
  ```
- **C**：清空字段；**⏎**：唯一主动作键（`ImeEnterKeyConfig`；**取消 SEND 文案 + 纸飞机图标**）

### 2.3 功能键视觉（Single 态）

**⌫**（键盘 A 符号层、键盘 B）及 **C / −**（键盘 B）与全局 Shift **Single** 一致：**灰底 + 橙色符号 + 1dp 橙边框**。  
**⏎**（各层唯一主动作键）保持 **全橙实心** 主键。  
**层切换键**（`123` / `ABC` / `#+=`）使用模式切换键样式（非 Single 橙框），与 QWERTY 上现有 `123` 一致。

### 2.4 QWERTY 底行 Profile（Email / Uri / Password 等）

全局 QWERTY **不复制整盘 Layout**；通过 **`ImeBottomRowProfile`** 替换默认底行键位。

默认 Text 底行：`123` · Space（加宽）· `.`（`,` 次选）· `⏎`


| Profile      | 底行调整（示例）                                            | 123 / 符号层                  |
| ------------ | --------------------------------------------------- | -------------------------- |
| **Text**     | 默认                                                  | 保留，可切换                     |
| **Email**    | 强化 `@`、可选 `**.com`** 后缀键；**不提供** `@gmail.com` 等默认域名 | **不禁用**；轻量化（不单独做 Email 整盘） |
| **Uri**      | 强化 `/` `:` 等（替换底行某一键或 Custom 键）                     | 同上                         |
| **Password** | 增加 **显示/隐藏**（👁）键；掩码由 Policy + `EditText` 控制        | 保留                         |
| **WiFi**     | 独立 Profile（非 Password）；Enter 标签可为 Connect           | 保留                         |


Email / Uri **Registry + BottomRowProfile 已完成**；Dialog 接入见 §8 Phase 5。

---

## 3. 三层模型 + Profile 扩展

```
ImeFieldType          业务字段类型（SignedDecimal / Email / …）
       │
       ▼
ImeFieldProfile       初始布局、可切换布局、Enter、InputPolicy、BottomRowProfile
       │
       ├─► ImeEnterKeyConfig     唯一主动作键 ⏎ 的标签/行为（Done / Connect / 换行）
       ├─► ImeBottomRowProfile   QWERTY 底行键位替换（Email / Uri / Password）
       └─► NumericPolicy           数字族按键拦截（Text/Password 无独立 Policy 类）
       │
       ▼
KeyboardLayoutId      纯 UI 行列（少量共享 Layout，不按 Field Type 膨胀）
```

### 3.1 `ImeFieldType`（对外 API）

```kotlin
enum class ImeFieldType {
    Text,
    Number,
    SignedDecimal,   // 合并原 NumberSigned + Decimal
    Email,
    Uri,
    Password,
    WiFi,            // 独立 Profile；Enter 可与 Password 共用 ImeEnterKeyConfig 实例
    // 扩展：Phone, Hex, Pin, …
}
```

> **Android 桥接**：`TYPE_NUMBER_FLAG_SIGNED` + `TYPE_NUMBER_FLAG_DECIMAL` 均映射 `**SignedDecimal`**，由 `NumericPolicy` 配置区分整数-only / 小数 / 有符号。

### 3.2 `ImeFieldProfile`（注册表条目）


| 字段                 | 含义                                           |
| ------------------ | -------------------------------------------- |
| `initialLayoutId`  | 首次弹出使用的布局                                    |
| `allowedLayoutIds` | 用户可切换的布局集合                                   |
| `enterKey`         | `ImeEnterKeyConfig` — **全键盘唯一主动作键 ⏎** 的语义与标签 |
| `bottomRowProfile` | QWERTY 底行键位替换（可选） |
| `numericPolicyConfig` | `NumericPolicyConfig`（Number / SignedDecimal） |
| `maskInput` | Password / WiFi 等是否掩码显示 |


### 3.3 `NumericPolicy`（Number / SignedDecimal / Stepper 统一）

**一个 Policy 类 + 配置**，替代 `IntegerInputPolicy` / `DecimalInputPolicy` / `SignedDecimalPolicy` 等多类型分叉：

```kotlin
data class NumericPolicyConfig(
    val allowSign: Boolean = false,      // `-` Leading minus
    val allowDecimal: Boolean = false,   // `.` 与单小数点
    val allowDoubleZero: Boolean = true, // `00` 键
    // Stepper / Dialog 范围校验仍留在 ui 层
)

object NumericPolicy : InputPolicy {
    fun forInteger() = NumericPolicyConfig()
    fun forSignedDecimal() = NumericPolicyConfig(allowSign = true, allowDecimal = true)
    // Number、SignedDecimal、FrostNumericStepper 共用此 Policy，仅 config 不同
}
```


| 场景                | Field Type                          | `NumericPolicyConfig`                 |
| ----------------- | ----------------------------------- | ------------------------------------- |
| 整数弹窗 / Stepper 整数 | `Number`                            | `allowSign=false, allowDecimal=false` |
| 有符号整数             | `Number` + config 或 `SignedDecimal` | `allowSign=true, allowDecimal=false`  |
| 小数 / 有符号小数        | `SignedDecimal`                     | `allowSign=true, allowDecimal=true`   |
| Stepper           | 同 Number / SignedDecimal            | 与 Dialog 共用 config，**不单独 Policy 类**   |


键盘 B **单一 Layout**（`DedicatedNumericLayout`）；Policy 拦截非法按键（如整数模式下的 `.`、第二次 `-`）。

### 3.4 `KeyboardLayoutId`（UI 资产，与 Field Type 解耦）


| LayoutId            | 实现参考                          | 用途                                           |
| ------------------- | ----------------------------- | -------------------------------------------- |
| `QwertyGlobal`      | `GlobalQwertyLayout`          | Text、Email、Uri、Password、WiFi（底行由 Profile 覆盖） |
| `SymbolsPrimaryA`   | `GlobalSymbolsPrimaryLayout`  | 键盘 A 123 / 主符号层                              |
| `SymbolsExtendedA`  | `GlobalSymbolsExtendedLayout` | 键盘 A `#+=` 扩展符号层                             |
| `NumericDedicatedB` | `DedicatedNumericLayout`      | Number、SignedDecimal、Stepper                 |


**已移除 / 不优先**：`NumericSignedB`、`DecimalB`、`EmailQwerty`、`UriQwerty`、`PasswordQwerty` 等 per-type 整盘 Layout。

**原则**：Layout 数量保持 **O(1) 级**（QWERTY + 2 符号层 + B 盘）；Field Type 差异走 **BottomRowProfile + Policy + EnterKeyConfig**。

---

## 4. 字段类型 → Profile 映射（已定）


| Field Type        | 初始布局              | 可切换布局         | BottomRowProfile         | Policy / 备注                                                                                 |
| ----------------- | ----------------- | ------------- | ------------------------ | ------------------------------------------------------------------------------------------- |
| **Text** | QwertyGlobal | QWERTY + 符号两层 | 默认 | 无 Policy 拦截 |
| **Number** | NumericDedicatedB | 仅 B | — | `NumericPolicy.forInteger()` |
| **SignedDecimal** | NumericDedicatedB | 仅 B | — | `NumericPolicy.forSignedDecimal()` |
| **Email** | QwertyGlobal | QWERTY + 符号两层 | **Email** | Registry ✅；Dialog 待接 |
| **Uri** | QwertyGlobal | QWERTY + 符号两层 | **Uri** | Registry ✅；Dialog 待接 |
| **Password** | QwertyGlobal | QWERTY + 符号两层 | **Password**（👁） | Registry ✅；Dialog 待接 |
| **WiFi** | QwertyGlobal | QWERTY + 符号两层 | WiFi | 已接入；Connect Enter |


**Password vs WiFi**：独立 `ImeFieldProfile` 条目（掩码、底行、业务回调可不同），仅 `**ImeEnterKeyConfig` 可复用**（例如共用 `customConnect()`），不合并 Profile。

**Email 后缀**：可提供 `**.com`** 一键键；**不建议**默认提供 `@gmail.com` 等具体域名（避免产品绑定 / 国际化问题）。

---

## 5. 弹出流程（统一链路）

所有 frost 弹窗共用 **同一条 attach / show / hide 管线**；仅 `ImeOverlaySpec` 中的字段类型不同。

```
FrostedGlassXxxDialog / EditText 宿主
    │
    │  ImeOverlaySpec.create(config, fieldType = SignedDecimal, onEditorAction)
    ▼
FrostPromptDialogController → ImeOverlayHost.attachOverlay
    │
    ▼
ImeOverlayHost.showKeyboardFor(editText)
    │
    ▼
ImeKeyboardOverlay.showForEditText(fieldType = spec.fieldType)
    │
    ▼
KeyboardController(profile = ImeFieldProfileRegistry.profile(fieldType))
    │
    ├─ layout ← profile.initialLayoutId
    ├─ bottomRow ← profile.bottomRowProfile（QWERTY 时）
    ├─ enterKey ← profile.enterKey（渲染唯一 ⏎）
    ├─ handleKey ← NumericPolicy.shouldCommit（B 盘）+ EditText InputFilter（ui 层）
    └─ toggleMode 仅当 allowedLayoutIds.size > 1
```

**不应** 在 Dialog 内写 `if (isEmail) showDifferentOverlay()`；只改 Spec 与 Registry。

### 5.1 与 Android `inputType` 的桥接（可选）

App 内键盘不依赖系统 IME，但建议提供推断，便于 `EditText` 默认对齐：

```kotlin
fun ImeFieldType.fromAndroidInputType(inputType: Int): ImeFieldType?
```


| Android 特征                               | 映射                                         |
| ---------------------------------------- | ------------------------------------------ |
| `TYPE_CLASS_NUMBER`，无 DECIMAL / SIGNED   | `Number`                                   |
| `TYPE_CLASS_NUMBER` + SIGNED 和/或 DECIMAL | `SignedDecimal`（`NumericPolicy` config 细分） |
| `TYPE_TEXT_VARIATION_EMAIL_ADDRESS`      | `Email`                                    |
| `TYPE_TEXT_VARIATION_URI`                | `Uri`                                      |
| `TYPE_TEXT_VARIATION_PASSWORD`           | `Password`                                 |
| 默认                                       | `Text`                                     |


**以 `ImeFieldType` 为弹键盘准**；`inputType` 作默认或二次校验。

---

## 6. 注册表示例

```kotlin
// 已实现：app/src/main/kotlin/com/lasercyber/lws/ime/field/ImeFieldProfileRegistry.kt
object ImeFieldProfileRegistry {
    fun profile(
        type: ImeFieldType,
        numericPolicyOverride: NumericPolicyConfig? = null,
    ): ImeFieldProfile = when (type) { /* Text, Number, SignedDecimal, Email, Uri, Password, WiFi */ }
}
```

`NumericPolicy` 职责：

- 拦截非法按键（第二次 `.`、整数模式下 `-`）
- Number / SignedDecimal / Stepper **同一实现**，config 区分
- 掩码、范围校验仍在 `EditText` / `FrostNumericStepperLogic`（ui 层）

---

## 7. 代码迁移映射


| 现有 | 目标 | 状态 |
|------|------|------|
| `ImeOverlaySpec.numericInput` | `fieldType` | ✅ |
| `KeyboardController(numericInput)` | `forFieldType(profile)` | ✅ |
| `FrostedGlassNumericInputDialog` | `Number` / `SignedDecimal` | ✅ |
| `FrostedGlassTextInputDialog` | `Text` | ✅ |
| `FrostedGlassWifiPasswordDialog` | `WiFi` | ✅ |
| Email / Uri / Password Dialog | 对应 `fieldType` | Phase 5 |


### 7.1 包结构（当前）

```
com.lasercyber.lws.ime
├── field/
│   ├── ImeFieldType.kt
│   ├── ImeFieldProfile.kt
│   ├── ImeFieldProfileRegistry.kt
│   ├── ImeBottomRowProfile.kt
│   ├── KeyboardLayoutId.kt
│   └── policy/NumericPolicy.kt
├── keyboard/layout/
│   ├── GlobalQwertyLayout.kt
│   ├── GlobalSymbolsPrimaryLayout.kt   // in KeyboardLayouts.kt
│   ├── GlobalSymbolsExtendedLayout.kt
│   └── DedicatedNumericLayout.kt
└── interop/
    ├── ImeOverlaySpec.kt
    └── ImeNumericFieldBridge.kt
```

---

## 8. 分阶段实施

> **原则**：Phase 1–4 = IME 内核；Phase 5 = 业务场景按需接入（可并行、可延后）。

### Phase 1 — 地基 ✅

- [x] `ImeFieldType`、`ImeFieldProfile`、`ImeFieldProfileRegistry`
- [x] `ImeOverlaySpec.fieldType`（`numericInput` deprecated）
- [x] `Text` → 键盘 A；`Number` → 键盘 B
- [x] 单元测试：Registry + 布局 golden

### Phase 2 — 数字族 ✅

- [x] `NumericPolicy` + `NumericPolicyConfig`
- [x] `SignedDecimal` + `ImeNumericFieldBridge`（Numeric Dialog）
- [x] 键盘 B `SEND` → `⏎`

### Phase 3 — 符号层 + BottomRowProfile ✅

- [x] `GlobalSymbolsPrimaryLayout` + `GlobalSymbolsExtendedLayout`（iOS 图二/图三）
- [x] 层切换：`123` / `ABC` / `#+=`；扩展层 `123` 返回主符号层
- [x] `ImeBottomRowProfile`（Email / Uri / Password / WiFi）
- [x] WiFi Dialog → `ImeFieldType.WiFi`
- [x] 无 EmailQwerty / UriQwerty 整盘

### Phase 4 — 文档与治理（进行中）

- [x] 本文档 + `.cursor/rules/ime-keyboard-baseline.mdc` 同步
- [x] `NumericPolicyTest` + Registry / Layout golden
- [ ] OpenSpec delta（可选，有 dialog spec 变更时）
- [ ] 集成测试（弹窗 E2E）

### Phase 5 — 场景接入（后续）

- [ ] Email 输入 Dialog → `ImeFieldType.Email`
- [ ] Uri 输入 Dialog → `ImeFieldType.Uri`
- [ ] 通用 Password Dialog → `ImeFieldType.Password`（WiFi 保持 `WiFi`）
- [ ] Stepper 显式传 `fieldType` / `NumericPolicyConfig`（可选，当前经 Numeric Dialog 间接）
- [ ] `allowDoubleZero=false` 等 config 按产品场景细调

---

## 9. 设计原则

1. **Field Type ≠ Layout 1:1** — Layout 保持 QWERTY + 2 符号层 + B 盘；差异走 Profile / Policy。
2. **Policy 不爆炸** — 数字族仅 `**NumericPolicy`**；SignedDecimal 是 config，不是新 Policy 类。
3. **Email / Uri 轻量化** — QWERTY + **BottomRowProfile**；123 / 符号层 **不禁用**。
4. **专用数字盘不切 abc** — Number / SignedDecimal 的 `allowedLayoutIds` 仅含 B。
5. **Password ≠ WiFi Profile** — 可共用 `**ImeEnterKeyConfig`**，不共用 Profile 条目。
6. **唯一主动作键 ⏎** — 各层右下仅一个；**取消 SEND + 纸飞机**；语义由 `ImeEnterKeyConfig` 注入。
7. **新增类型只改 Registry** — 禁止 Dialog 内 scattered `if (email)`。
8. **样式按 KeyId** — Single 功能键、Shift 三态、⏎ 主键规则与 Field Type 无关。
9. **Overlay 管线稳定** — attach、backdrop、touch slot 不随 Field Type 分裂。

---

## 10. 待设计细节（剩余）

### 10.1 NumericPolicy / Stepper（Phase 5）

- `allowDoubleZero=false` 是否在部分整数 Dialog 启用？
- Stepper 是否显式传 `fieldType`（当前经 Numeric Dialog Spec 间接）

### 10.2 场景接入（Phase 5）

- Email / Uri / Password 具体 Dialog 宿主与迁移顺序
- Password Dialog 是否与 WiFi 共用布局、仅 `fieldType` 不同

### 10.3 已关闭

- ~~扩展层返回主符号层~~ → **扩展层 `123` 键**
- ~~QWERTY 底行 `@` vs `.`~~ → **`.` 覆盖 `@`，空格加宽**
- ~~`,/.` 顺序~~ → **`,` 在 `.` 左（符号层与 QWERTY 一致）**

---

## 11. 已确认决策（摘要）


| 议题                     | 决策                                                   |
| ---------------------- | ---------------------------------------------------- |
| NumberSigned + Decimal | 合并为 `**SignedDecimal`** + `**NumericPolicy**` config |
| Stepper                | 与数字 Dialog **共用 NumericPolicy**，不单独 Policy 类         |
| Email / Uri Layout     | **不 rush 整盘**；QWERTY + **BottomRowProfile**          |
| Email 后缀               | `**.com` 可以有**；`**@gmail.com` 不建议默认**                |
| 123 / 符号层              | **不禁用**；Email / Uri 仅轻量化                             |
| Password               | **建议加显示/隐藏键**                                        |
| Password vs WiFi       | **Profile 不共用**；**EnterKeyConfig 可共用**               |
| 主动作键                   | **单层仅一个 ⏎**；**SEND + 纸飞机 → ⏎**                       |


---

## 12. 测试策略


| 层级       | 内容                                                                  |
| -------- | ------------------------------------------------------------------- |
| Registry | 每种 `ImeFieldType` 的 `initialLayoutId`、`allowedLayoutIds`            |
| Layout   | 行列 golden（已有 `KeyboardControllerPopupTest` 模式）                      |
| Policy   | `NumericPolicy` config 矩阵；SignedDecimal 双点 / 负号；Stepper 与 Dialog 一致 |
| 集成       | 弹窗打开 → 键盘种类 → 按键 → EditText 文本（含不 OOM、不重复 show）                     |


---

## 13. 修订记录


| 日期      | 说明                                                                                                        |
| ------- | --------------------------------------------------------------------------------------------------------- |
| 2026-06 | 初版：Field Type 三层模型、A/B 基线、迁移阶段与 Registry 规划                                                               |
| 2026-06 | 键盘 A 123 改为主符号层 + `#+=` 扩展符号层（替换旧 4×4 电话盘）                                                                |
| 2026-06 | 主符号层：4 行布局；底行 `ABC [space] ⏎`（图一 Search 位改 ⏎）                                                             |
| 2026-06 | Policy 收敛：SignedDecimal + NumericPolicy；Email/Uri 底行 Profile；Password 显示/隐藏；WiFi 独立 Profile；单层唯一 ⏎；SEND→⏎ |
| 2026-06 | 符号层对齐 iOS 图二/图三；QWERTY 底行 `.` 替 `@`、空格加宽；Phase 5 场景接入拆分 |
| 2026-06 | Phase 1–3 标记完成；baseline rule 同步；`NumericPolicyTest` |


