## ADDED Requirements

### Requirement: AssetDeployer 工具类

系统 SHALL 提供 `AssetDeployer` 类（包路径 `com.lasercyber.lws.ai`），负责将 `assets/config.yaml`（由 YOLO 团队 ZIP 包提供，已合并到 `app/src/main/assets/`）解压到 App 内部存储的运行时路径。

#### Scenario: 首次启动解压
- **WHEN** App 首次启动且 `files/lens_guard/config.yaml` 不存在
- **THEN** SHALL 从 `assets/config.yaml` 读取内容并写入 `context.getFilesDir()/lens_guard/config.yaml`

#### Scenario: 已存在时跳过
- **WHEN** `files/lens_guard/config.yaml` 已存在
- **THEN** SHALL 跳过解压，直接返回已有文件路径

### Requirement: 运行时目录结构

解压后 SHALL 形成以下目录结构：
```
/data/data/<包名>/files/lens_guard/
├── config.yaml
└── debug_data/         ← 引擎自动创建
```

#### Scenario: 目录自动创建
- **WHEN** `files/lens_guard/` 目录不存在
- **THEN** `AssetDeployer` SHALL 自动创建该目录（含所有父目录）

### Requirement: 路径输出

`AssetDeployer.deploy(Context context)` SHALL 返回一个包含两个路径的结果对象：
- `configPath`：`config.yaml` 的绝对路径
- `projectRoot`：`lens_guard/` 目录的绝对路径

#### Scenario: 返回有效路径
- **WHEN** 解压成功或文件已存在
- **THEN** 返回的 `configPath` SHALL 指向一个可读的文件，`projectRoot` SHALL 指向一个存在的目录

### Requirement: assets 中包含 config.yaml

`app/src/main/assets/` 目录下 SHALL 包含 `config.yaml` 文件，该文件由 YOLO 团队提供，包含算法参数和 GPIO 配置。

#### Scenario: config.yaml 已打包
- **WHEN** APK 被构建
- **THEN** `assets/config.yaml` SHALL 被包含在最终 APK 中
