## 数据模型说明（精简版）

### 设计原则
- **扩展优先**：新增健康指标优先走 `measurement_type` + `measurement`，避免频繁加新表。
- **时间序列优先**：绝大多数健康数据本质是“在某个时间点测得一个值”。
- **尽量少的强枚举**：除关键字段（`source.kind`、`measurement_type.value_kind` 等）外，多用自由文本，方便迭代。

### 核心实体
- **人**
  - `person`：主体
  - `person_profile`：人口统计学与相对静态信息（可按需扩展）
- **来源**
  - `source`：设备、应用、手动、导入；用于追踪数据可信度与可追溯性
- **指标体系**
  - `measurement_type`：指标字典（code 唯一且稳定）
  - `measurement`：实际测量数据（支持 number/text/json 三种 value 形态）

### 领域表（结构化会话/事件）
- `activity_session`：运动会话（开始/结束/步数/距离/热量等）
- `sleep_session`：睡眠会话（开始/结束/质量）
- `food_item`、`nutrition_intake`：食物库与摄入记录
- `medication`、`medication_intake`：用药计划与服用事件
- `condition`、`symptom`：疾病与症状

### 常见扩展方式
- **新增指标**：往 `measurement_type` 插入一行；写入 `measurement`。
- **新增“会话型数据”**（如冥想、康复训练、理疗）：参考 `activity_session` 建新表，保留 `person_id` + `start_at/end_at` + `source_id`。
- **更复杂的结构化指标**（如血脂四项、体检报告）：可用 `measurement.value_json` 先落地，再决定是否拆专表。


