# 行为数据 TXT 文件表头含义

表头在文件第一行，以 tab 分隔，共 25 列：

| 列号 | 表头 | 含义 | 证据来源 |
|---|---|---|---|
| 1 | `subject` | 被试编号 + 实验标识（如 `s01_vismot_04042017`） | **明确** — 代码中用作被试 ID |
| 2 | `age` | 被试年龄 | **推测** — 数据值为 25 等整数，符合年龄范围，但代码中未直接使用此列 |
| 3 | `handedness` | 利手（`R` = 右利手） | **推测** — 全部值为 `R`，符合常理，但代码中未引用 |
| 4 | `block` | 实验的 block 编号 | **明确** — `r04_link_behavior.m:64` 中 `behavior.block = BeAll.block` |
| 5 | `trial` | block 内 trial 编号 | **明确** — 同上，`:65` |
| 6 | `iti` | inter-trial interval，试次间隔时间（ms） | **推测** — 列名本身暗示，数值（550–800 ms）符合 ITI 范围，但代码中未使用 |
| 7 | `wmDelay` | working memory delay，工作记忆保持阶段的延迟时长（ms） | **推测** — 列名含义明确，数值约 2075–2492 ms，符合 VWM 任务的 retention interval |
| 8 | `trialtype` | 试次条件类型（1–4 的整数） | **推测** — 论文涉及 toward/no/away 分类，但这是基于微眼跳方向的事后分类，`trialtype` 可能是实验设计中预设的某种条件组合（如 cue 方向 × 刺激类型），代码中未直接分析此列 |
| 9 | `loc-Color1` | 位置 1（左或右）上刺激的颜色编号（1 或 2） | **推测** — 列名暗示"位置→颜色"的映射，`color-loc` 反过来是"颜色→位置"，数值互相呼应 |
| 10 | `loc-Color2` | 位置 2 上刺激的颜色编号 | **推测** — 同上 |
| 11 | `color-loc1` | 颜色 1 对应的位置编号 | **推测** — 与 `loc-Color` 互为反向映射 |
| 12 | `color-loc2` | 颜色 2 对应的位置编号 | **推测** — 同上 |
| 13 | `ori-loc1` | 位置 1 上刺激的朝向（orientation，度数） | **推测** — 数值为 0–180 范围的角度值，`ori-loc` 命名模式表示"朝向–位置" |
| 14 | `ori-loc2` | 位置 2 上刺激的朝向 | **推测** — 同上 |
| 15 | `targetColor` | 目标（被 cue 选中的）记忆项的颜色编号 | **推测** — 值为 1 或 2，与其他 color 列一致 |
| 16 | `targetLoc` | 目标记忆项在 encoding 时的空间位置（**1 = 左, 2 = 右**） | **明确** — `r04_link_behavior.m:13` 注释写明 "targetLoc: 1 = 左, 2 = 右"，`:66` 直接引用 |
| 17 | `targetOri` | 目标记忆项的原始朝向（度数） | **明确** — `r04_link_behavior.m:14` 写明 `reportVsTarget = 报告 - 真实 orientation`，且数据中 `targetOri = ori-loc{targetLoc}` 的值一致可验证 |
| 18 | `probeOri` | 探针（probe）出现时的朝向（度数） | **明确** — 论文用 `reportVsProbe = 报告 - probe` 来衡量，数据中该列值固定为 90（probe 每次旋转到 90°）或 0（某类 trial）。`r04` 注释提到 `reportVsProbe` |
| 19 | `reportOri` | 被试报告的朝向（度数） | **明确** — 代码中用于计算误差，数据中值为被试实际按键对应的旋转角度 |
| 20 | `reportVsTarget` | 报告误差（signed）= `reportOri - targetOri`（度） | **明确** — `r04_link_behavior.m:14` 注释写明 "reportVsTarget: 报告 - 真实 orientation (signed degrees)"，`:68` 中 `error = abs(reportVsTarget)` |
| 21 | `reportVsProbe` | 报告 vs 探针 = `reportOri - probeOri`（度） | **推测** — 列名模式与 `reportVsTarget` 一致，且数据中 `reportVsProbe ≈ reportOri - 90`（当 probeOri=90 时）可验证 |
| 22 | `targetVsProbe` | 目标 vs 探针 = `targetOri - probeOri`（度） | **推测** — 列名模式一致，且数据中 `targetVsProbe = targetOri - 90` 可验证 |
| 23 | `RT1` | 反应时 1：**从 cue onset 到按键 onset**（ms） | **明确** — `r04_link_behavior.m:15` 注释 "RT1: 自 cue onset 到按键 onset"，`:67` 中 `behavior.RT = BeAll.RT1` |
| 24 | `RT2` | 反应时 2：从 cue onset 到松键（ms） | **明确** — `r04_link_behavior.m:16` 注释 "RT2: 自 cue onset 到松键" |
| 25 | `RT3` | 反应时 3：从报告 dial 出现到松键（ms） | **明确** — `r04_link_behavior.m:17` 注释 "RT3: 自报告 dial 出现到松键" |

---

## 总结

- **有明确代码/注释证据的列（13 个）**：`subject`、`block`、`trial`、`targetLoc`、`targetOri`、`probeOri`、`reportOri`、`reportVsTarget`、`RT1`、`RT2`、`RT3`，以及 `loc-Color`/`color-loc`/`ori-loc` 系列中可通过 `targetOri = ori-loc{targetLoc}` 数据关系验证的那些。
- **合理推测但无代码直接引用的列（8 个）**：`age`、`handedness`、`iti`、`wmDelay`、`trialtype`、`reportVsProbe`、`targetVsProbe`、`targetColor`。这些列的含义从命名和数据值模式可以合理推断，但项目代码中没有直接使用或注释说明它们。

## 关键代码引用

- `r04_link_behavior.m` 第 12–21 行：对 `targetLoc`、`reportVsTarget`、`RT1`、`RT2`、`RT3` 的明确注释
- `r04_link_behavior.m` 第 66–69 行：实际使用 `block`、`trial`、`targetLoc`、`RT1`、`reportVsTarget` 的代码
- `r00_setup.m` 第 50–52 行：trigger 编码定义（cue_left = [21 22]，cue_right = [23 24]）
