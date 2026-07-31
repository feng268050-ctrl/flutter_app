# C++ 后处理（det / cls）

与 `pt2onnx2rknn.md` 中约定一致：ONNX/RKNN 只保留**模型前向**输出，不内置 NMS 与后处理。**检测**解码、DFL、NMS、letterbox 还原的权威实现在 **`cpp/postprocess/det_postprocess.{hpp,cpp}`**（`det_postprocess` 命名空间）。部署约定见 **`docs/训练推理后处理对齐说明.md`**（当前 `det_raw_head`：三路 `[1,65,H,W]`，拼接后 **raw DFL**，`N=33600`，stride `[4,8,16]`）。`ModelManager::infer_stain` 负责三路拼接；`postprocess_det` 为薄封装。

不要写死 `8400`（默认 P3/P4/P5）；P2/P3/P4 在 640 输入下为 **33600**。通道维 `C` 为 **65**（raw）或 **5**（decoded）；由 `num_features` 自动判定。

## 头文件

- **检测（共享）**：`cpp/postprocess/det_postprocess.hpp`
- **封装 + 分类**：`yolo_postprocess.hpp` / `yolo_postprocess.cpp`

部署侧调用仍使用 `yolo_postprocess::postprocess_det`；传入 `DetConfig::input_imgsz`（默认 640）以匹配 letterbox 方形边长，`ModelManager` 会从配置的 `stain_input_size` 写入。

## 如何传入模型输出

### 检测 `postprocess_det`

1. 从推理引擎取出**浮点**张量（RKNN INT8 须先按各输出 `scale`/`zero_point` 反量化，见对齐说明 §8.2）。`det_raw_head` 为 **3 路** `[1,65,H,W]`，由 `ModelManager` 拼成 `[65,N]` 再调用；单路 decoded `[1,5,N]` 仍支持。若有 batch 维 `[1, ...]`，先 squeeze 到两维 `[d0,d1]`。

2. 令 `DetConfig::num_classes`：传 **`0`（默认）** 表示与 `check/onnx_infer.py` 相同，由通道数自动判定 **decoded**（`4+nc`）或 **raw DFL**（`4*reg_max+nc`）。若传 **`nc ≥ 1`**，则按该 `nc` 解析通道布局。两维中**必有一维等于当前头对应的 C**：

   - `[C, N]`：小维为 C 在前的 `[C, N]`，元素 `(f, n)` 下标为 `f * N + n`（与 `[1, C, N]` 展平一致）。

   - `[N, C]`：大维为 C 的 `[N, C]`，元素 `(n, f)` 下标为 `n * C + f`（与 `[1, N, C]` 展平一致）。

3. 将 `d0`、`d1` 与数据指针、以及 `DetConfig`、`LetterboxInfo`（`scale=1`、`pad=0`，模型输入 640×640）交给 `postprocess_det`，并传入 `StainDetRoiRestore`（`crop_s=700`、`crop_x0/y0` 等，按 `700/640` 还原到全帧）。

4. 若检测模型输出类别 logits，将 `DetConfig::class_scores_are_logits` 置为 `true`，模块会先对类别分数做 sigmoid 再阈值过滤；若输出已是概率，保持默认 `false`。

5. **INT8 量化 / RKNN 非 FP32 输出**：先把输出反量化或转换为 `float` 再调用；本模块不对定点布局做假设。

### 分类 `postprocess_cls`

1. 输入为一维 `num_classes` 个 `float`（`[1, num_classes]` 去掉 batch 后）。若为 logits 会先数值稳定 `softmax`；若各分量之和已接近 1.0 则按概率使用（与 `check/cls_onnx_infer.py` 的启发式一致）。

2. 量化张量同样需先转 `float` 再调用。

## 构建与自检

在仓库内（需已安装 CMake 与 C++ 工具链）：

```text
cd cpp
cmake -B build
cmake --build build
```

运行 `build/test_postprocess`（Linux/macOS）或 `build/Debug/test_postprocess.exe`（Windows）应打印 `all tests passed`。

### 与 Python / ONNX 的对比

仓库根目录脚本（需安装 `onnxruntime`）可用于 ONNX 输出与手写 Python 后处理对照：

```bash
python compare_onnx_cpp_postprocess.py --help
```

## 不涵盖的内容

- 不负责 ONNX Runtime / RKNN 推理、张量从设备拷贝或反量化，仅对 `float` 缓冲区做后处理。
