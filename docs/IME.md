# RK3566 / Android 11 / Compose IME 无法点击问题定位

## 结论

当前 `frostui` 里的键盘更像是 **App 内部自定义键盘 Overlay**，不是标准系统 IME。

`AndroidManifest.xml` 中目前没有看到标准 IME 必需的：


```
android.permission.BIND_INPUT_METHOD
android.view.InputMethod
InputMethodService
```

当前主要是 Activity、普通 Service、Provider、Receiver 注册。

---

## 最可能原因

### 1. 键盘挂载位置不稳定

`ImeKeyboardOverlay` 中存在 fallback 逻辑：


```
return slot ?: overlayRoot
```

如果找不到 `frosted_glass_ime_slot`，键盘会直接挂到 `overlayRoot`。这会导致触摸区域、视觉位置、层级不一致。

**风险：**


```
看得到键盘，但点击事件没有命中按键区域
```

---

### 2. `TouchHost` 占用全屏触摸区域

当前 `ImeKeyboardTouchHost` 使用：


```
MATCH_PARENT x MATCH_PARENT
```

并且 `onTouchEvent()` 最后返回：

```
return true
```

这表示它会吃掉未处理的触摸事件。

**风险：**

```
触摸被宿主层消费，Compose 按键收不到点击
```

---

### 3. Compose 按键本身有点击逻辑

`ImePrimaryKeyShell`、`ImeDefaultKeyShell` 都已经使用 `.clickable {}`，说明按键层本身不是完全没绑定点击事件。

所以优先怀疑：

```
View 层级 / 触摸区域 / Overlay 宿主
```

而不是按键 Composable 本身。

---

## 优先修复点

### 修复 1：不要 fallback 到 `overlayRoot`

改前：

```
private fun resolveImeHost(overlayRoot: ViewGroup): ViewGroup {
    val slotId = FrostResourceIds.viewId(
        overlayRoot.context,
        "frosted_glass_ime_slot"
    )
    val slot = overlayRoot.findViewById<ViewGroup>(slotId)
    return slot ?: overlayRoot
}
```

建议改为：

```
private fun resolveImeHost(overlayRoot: ViewGroup): ViewGroup? {
    val slotId = FrostResourceIds.viewId(
        overlayRoot.context,
        "frosted_glass_ime_slot"
    )
    return overlayRoot.findViewById<ViewGroup>(slotId)
}
```

调用处：

```
val imeHost = resolveImeHost(overlayRoot) ?: run {
    Log.e("FrostIme", "frosted_glass_ime_slot not found")
    return
}
```

---

### 修复 2：`TouchHost` 只占键盘高度

不要使用全屏：

```
MATCH_PARENT x MATCH_PARENT
```

建议改成：

```
val touchHost = ImeKeyboardTouchHost(activity).apply {
    layoutParams = FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        panelHeightPx,
        Gravity.BOTTOM
    )

    addView(
        composeView,
        FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    )
}
```

重点：

```
高度 = panelHeightPx
位置 = Bottom
```

---

### 修复 3：确认 `frosted_glass_ime_slot` 真实存在

`frosted_glass_ime_slot` 必须：

```
存在
在底部
有明确高度
位于最上层
clipChildren = false
clipToPadding = false
```

示例：

```
<FrameLayout
    android:id="@+id/frosted_glass_ime_slot"
    android:layout_width="match_parent"
    android:layout_height="@dimen/ime_keyboard_height"
    android:layout_gravity="bottom"
    android:clipChildren="false"
    android:clipToPadding="false" />
```

---

## 排查日志

在 `ImeKeyboardTouchHost` 加：

```
override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    Log.d(
        "FrostImeTouch",
        "dispatch action=${event.actionMasked}, x=${event.x}, y=${event.y}, w=$width, h=$height"
    )
    parent?.requestDisallowInterceptTouchEvent(true)
    return super.dispatchTouchEvent(event)
}
```

在按键点击里加：

```
.clickable {
    Log.d("FrostImeTouch", "key clicked")
    onClick()
}
```

判断：

```
无 dispatch 日志：
触摸没进入键盘 View，检查 z-order / bounds / slot。

有 dispatch，无 key clicked：
触摸进入宿主，但没命中 Compose 按键。

有 key clicked，无输入：
点击正常，问题在 InputConnection / commitText。
```

---

## Android 11 / RK3566 注意点

Android 11 是 API 30，不是 API 31。  
 IME 场景不建议先上实时高斯模糊，尤其是 RK3566。

建议先用纯色背景验证点击：

```
Box(
    modifier = Modifier
        .fillMaxSize()
        .background(Color(0xFF2A2D38))
)
```

点击正常后，再恢复模糊效果。

---

## 最小修复顺序

```
1. resolveImeHost() 不允许 fallback 到 overlayRoot
2. TouchHost 高度改为 ime_keyboard_height
3. 确认 frosted_glass_ime_slot 存在且有真实高度
4. 临时关闭高斯模糊
5. 加 dispatchTouchEvent / key clicked 日志
6. 再排查 InputConnection
```

## 核心判断

```
当前问题优先看 View 层级和触摸命中区域，
不是 Jetpack Compose 按键 clickable 本身的问题。
```

