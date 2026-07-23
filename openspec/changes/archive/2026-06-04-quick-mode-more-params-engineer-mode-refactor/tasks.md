## 1. ProcessDataType 与数据层

- [x] 1.1 在 `ProcessDataType` 中新增 `ENGINEER_MODE_DATA = 1`，将 `ENGINEER_MODE_DEFAULT_DATA` / `ENGINEER_MODE_CUSTOM_DATA` 标记为 `@Deprecated` 别名或废弃常量
- [x] 1.2 更新 `ProcessParametersDataDao` 查询：工程师模式仅查 `dataType = 1`（过渡期可读 `IN (1,2)` 直至 migration 完成）
- [x] 1.3 新增 Room migration：将现有 `dataType = 2` 行更新为 `1`
- [x] 1.4 更新 `ProcessDataExcelConvert.convertProcessDataType`：支持「工程师模式常用参数」标签，legacy 自定义类型归一化为 `1`

## 2. Bootstrap 与中位档导入

- [x] 2.1 在 `ProcessDataExcelConvert` 增加 `toEnglishMaterialName` 供 bootstrap 命名使用
- [x] 2.2 重写 `ProcessLibraryImporter.ensureEngineerModeDefaults`：按 `processType` 从快速模式行选取中位 gear + 中位 thickness/swingWidth，clone 为 `ENGINEER_MODE_DATA`，名称设为所选行的英文材料名
- [x] 2.3 更新 `resetAllProcessData` 删除范围：替换 `ENGINEER_MODE_DEFAULT_DATA` 为 `ENGINEER_MODE_DATA`
- [x] 2.4 补充/更新 `ProcessLibraryImporter` 单元测试（中位选取、英文材料命名、无重复 clone）

## 3. 工程师模式 ViewModel 与重置语义

- [x] 3.1 在 `ProcessParametersDataViewModel` 增加 `sessionBaseline`：在 `switchProcessParametersData` 及快速模式入口加载时深拷贝保存
- [x] 3.2 重写 `resetDefaultData`：恢复 `sessionBaseline`，移除对 `originId` / 内置默认行的依赖
- [x] 3.3 更新 `saveCommonlyUsedParameter`：新行/更新均使用 `ENGINEER_MODE_DATA`，不再写入 `dataType = 2`
- [x] 3.4 更新 `EngineerWeldingFragment` / `EngineerWashFragment` / `EngineerCuttingFragment` 重置按钮行为与相关 Toast/禁用逻辑

## 4. 快速模式「更多参数」入口

- [x] 4.1 新增字符串资源 `more_parameters_text`（中/英）及图标 drawable
- [x] 4.2 在 `activity_quick_mode.xml` 右上角添加带图标的「更多参数」按钮，绑定可见性（非 CNC、非 laser overlay、非 cncOpening）
- [x] 4.3 在 `GeneralOperationsFragment` 暴露 `findNowProcessParametersData()` 或等价 getter 供 Activity 调用
- [x] 4.4 在 `QuickModeActivity` 实现点击：校验匹配行 → `Intent` 启动 `EngineerModeActivity`（含 processType + 参数快照/id），遵守 `DeviceRemoteLockPolicy`
- [x] 4.5 在 `EngineerModeActivity` 解析 Intent：切换对应 Tab、加载参数、初始化 session baseline

## 5. 远程 API 与推送

- [x] 5.1 更新 `DeviceWsProcessParametersPayload` / WS handler：create 使用 `ENGINEER_MODE_DATA`；delete 允许 `dataType = 1`；list 语义对齐
- [x] 5.2 更新 `ProcessParametersRemoteService`（HTTP）与 `ServerPushMessageHandler` 保持一致
- [x] 5.3 更新 `DeviceWsProcessParametersPayloadTest`、`ProcessParametersRemoteServiceTest` 及相关测试

## 6. 验证

- [x] 6.1 手动验证：连续焊/点焊/清洗/手持切割快速模式显示按钮，CNC 切割不显示
- [x] 6.2 手动验证：更多参数跳转后工程师模式参数与快速模式当前选择一致；重置恢复跳转时快照
- [x] 6.3 运行相关单元测试并修复失败用例
