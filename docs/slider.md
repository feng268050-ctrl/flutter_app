# FrostSlider 长按防误触优化方案

## 1. 当前问题

当前 Slider 已支持长按放大圆点，但仍存在误触问题：

```text
按住圆点
未等圆点放大
左右滑动
Slider value 和 thumb 已经发生变化
```

核心原因是：**value 更新逻辑触发过早**。
当前实现中，长按成功或按压移动过程中，已经使用手指当前位置计算并更新 value。

---

## 2. 目标交互

```text
长按圆点 → 圆点放大 → 放大完成 → 左右移动 → 才允许修改 value
```

要求：

1. 点击滑轨不改变数值。
2. 短按圆点不改变数值。
3. 圆点未放大前，左右移动不改变数值。
4. 圆点放大完成后，左右移动才更新 value。
5. 松手后圆点恢复默认大小。
6. 放大后的圆点不能被父容器裁切。

---

## 3. 状态拆分

当前不应只用一个 `isDragArmed` 状态。
建议拆成两个状态：

```kotlin
class FrostSliderLongPressDragState {
    var isThumbExpanded by mutableStateOf(false)
    var isValueArmed by mutableStateOf(false)
    var dragFraction by mutableFloatStateOf(Float.NaN)
}
```

含义：

| 状态                | 作用             |
| ----------------- | -------------- |
| `isThumbExpanded` | 控制圆点是否放大       |
| `isValueArmed`    | 控制是否允许修改 value |
| `dragFraction`    | 拖动中的临时进度       |

---

## 4. 核心规则

### 错误逻辑

```text
长按成功 → 立即根据当前位置更新 value
```

### 正确逻辑

```text
长按成功 → 圆点放大
放大完成 → 记录 activationX
之后的左右移动 → 才更新 value
```

---

## 5. `onArm` 不应更新 value

当前 `onArm` 中不应执行：

```kotlin
onProgressChange(...)
```

建议改为只进入状态：

```kotlin
onArm = {
    onStartTracking?.invoke()
    dragState.dragFraction = restingFraction
}
```

真正的 value 更新只放到：

```kotlin
onValueChangeWhileArmed = { activationX, x ->
    val deltaFraction = (x - activationX) / travel
    val fraction = (restingFraction + deltaFraction).coerceIn(0f, 1f)

    dragState.dragFraction = fraction
    onProgressChange(
        frostSliderProgressFromFraction(fraction, min, max),
        true
    )
}
```

重点：**使用位移增量计算，不使用手指绝对坐标计算。**

---

## 6. 长按前移动应取消操作

为了防误触，长按未成功前如果手指移动超过 `touchSlop`，应取消本次操作：

```kotlin
if (!thumbExpanded && abs(change.position.x - downX) > touchSlop) {
    break
}
```

效果：

```text
按住圆点后立即滑动 → 不触发拖动 → 不修改 value
```

---

## 7. 需要同步修改的文件

```text
FrostSliderLongPressDragGesture.kt
FrostSlider.kt
FrostCapsuleSlider.kt
```

其中：

| 文件                                   | 修改点                                   |
| ------------------------------------ | ------------------------------------- |
| `FrostSliderLongPressDragGesture.kt` | 拆分 `isThumbExpanded` / `isValueArmed` |
| `FrostSlider.kt`                     | `onArm` 不再更新 value                    |
| `FrostCapsuleSlider.kt`              | 同步修复相同拖动逻辑                            |

---

## 8. 放大圆点被裁切

当前圆点放大后可能被父容器遮挡。
建议增加 thumb overflow：

```xml
<dimen name="frost_slider_thumb_drag_overflow">8dp</dimen>
```

如仍被裁切，可调整为：

```xml
<dimen name="frost_slider_thumb_drag_overflow">10dp</dimen>
```

同时确保 Slider 外层容器：

```kotlin
clipChildren = false
clipToPadding = false
```

但优先方案是：**增加 Slider 自身高度和 overflow，让放大后的圆点仍在 Slider bounds 内。**

---

## 9. 最小修改清单

```text
1. 拆分拖动状态：isThumbExpanded / isValueArmed
2. onArm 只触发状态，不更新 value
3. value 更新只允许在 isValueArmed = true 后执行
4. 使用 activationX + delta 计算拖动值，避免跳变
5. 长按前移动超过 touchSlop 直接取消
6. FrostSlider 和 FrostCapsuleSlider 同步修改
7. thumb overflow 从 5dp 调整到 8dp 或 10dp
```

---

## 10. 验收标准

```text
1. 点击滑轨，数值不跳转。
2. 短按圆点，数值不变化。
3. 按住圆点但未放大时左右滑动，数值不变化。
4. 圆点放大完成后左右滑动，数值才变化。
5. 松手后圆点恢复默认大小。
6. 放大圆点不被卡片或 Slider 区域裁切。
```

## 11. 核心结论

```text
Slider value 更新必须绑定到 isValueArmed 状态。
圆点未放大完成前，所有 move 事件都应被消费，但不得更新 value。
```
