# Agent Prompt: 将 FieldTrip 集成到眼动分析管线

请帮我修改仓库 `c:\MATLABEMM\MATLABWorkspaceEMM\VWMMS_EEG_alpha-covertAttention` 中 `code/reproduce/` 目录下的眼动分析管线，在合适的步骤引入 FieldTrip 工具箱，并移除不再需要的 Engbert-Kliegl 模块。

---

## 一、背景与目标

本仓库复现论文 "Functional but not obligatory link between microsaccades and neural modulation by covert spatial attention" (Liu, Nobre & van Ede, 2022) 的眼动分析管线。当前管线全部使用自定义 MATLAB 代码。原作者在实际分析中使用了 FieldTrip（数据结构为 FieldTrip 格式，cluster permutation 使用 FieldTrip 实现）。我需要你修改现有管线，在原作者使用了 FieldTrip 的步骤引入 FieldTrip，同时保留自定义实现作为可切换的备选方案。

**具体目标：**
1. 在 `r00_setup.m` 中添加 `cfg.use_fieldtrip` 全局开关
2. 当 `cfg.use_fieldtrip = true` 时：数据导入/epoching 使用 `ft_read_event` + `ft_preprocessing`；cluster permutation 使用 `ft_timelockstatistics`
3. 当 `cfg.use_fieldtrip = false` 时：管线行为必须与修改前完全一致
4. 微眼跳检测算法（PBlab）、trial 分类、行为分析等原作者自定义逻辑保持不变
5. **移除 Engbert-Kliegl 模块**（r07 + helper_engbert_kliegl.m）：该部分在论文中仅作为补充材料（Supplementary Fig 7），不属于核心分析，从管线中彻底删除
6. 所有代码修改完成后，更新 4 个学习文档以对齐最新管线

---

## 二、需要修改的文件

| 文件 | 修改内容 |
|------|---------|
| `r00_setup.m` | 添加 `cfg.use_fieldtrip` 开关 |
| `r01_prepare_eye_data.m` | 添加 FieldTrip 数据导入/epoching 分支 |
| `r06_group_rate_clusterperm.m` | 添加 FieldTrip cluster permutation 分支 |
| `run_all.m` | 移除 r07 步骤，添加 FieldTrip 路径加载 |

**不修改的文件：** r02（PBlab 检测）、r03（trial 分类）、r04（行为对齐）、r05（RM-ANOVA）、`helper_parse_asc.m`、`helper_cluster_perm_1d.m`、`code/` 根目录下的原始作者代码。

---

## 三、需要删除的文件

以下文件属于 Engbert-Kliegl 模块，从管线中彻底移除：

| 文件 | 说明 |
|------|------|
| `code/reproduce/r07_engbert_kliegl.m` | EK2003 检测 + Sup Fig 7 生成脚本 |
| `code/reproduce/helper_engbert_kliegl.m` | EK2003 微眼跳检测算法实现 |

同时删除 r07 产生的输出文件（如果存在）：
- `results/EK_microsaccades_s*.mat`
- `results/EK_rate_timecourse.mat`
- `results/figures/sup_fig7_EK_rate.png`

---

## 四、FieldTrip 路径

FieldTrip 安装在 `C:\MATLABEMM\MATLABAddOnEMM\fieldtrip-20241219`。`r00_setup.m` 中已有 `cfg.fieldtrip_dir` 字段和 `cfg.add_fieldtrip` 函数句柄。在调用任何 `ft_*` 函数前，必须先调用 `cfg.add_fieldtrip()` 确保路径已添加。

---

## 五、各文件详细修改说明

### 5.1 `r00_setup.m`

在 cfg 结构体中添加一行：

```matlab
cfg.use_fieldtrip = true;  % true = 使用 FieldTrip, false = 使用自定义实现
```

确认 `cfg.add_fieldtrip` 函数句柄能正确将 `cfg.fieldtrip_dir` 添加到 MATLAB 路径。

### 5.2 `r01_prepare_eye_data.m` — 数据导入和 epoching

**这是改动最大的步骤。** 需要在主循环中（对每个被试、每个 session）根据 `cfg.use_fieldtrip` 分支。

#### 当 `cfg.use_fieldtrip = true` 时，替换"步骤 1：解析 ASC"为：

```matlab
% 读取事件
event = ft_read_event(asc_file);
% 提取 trig 21-24 的 cue 事件
cue_mask = ismember([event.value], cfg.trig.cue_left | cfg.trig.cue_right);
cue_events = event(cue_mask);
cue_samples = [cue_events.sample];

% 构建 trl 矩阵：[begsample, endsample, offset, trigger_code]
pre_samples  = round(cfg.epoch(1) * cfg.fs);  % -1000 ms
post_samples = round(cfg.epoch(2) * cfg.fs);  % +2000 ms
trl = zeros(length(cue_events), 4);
for k = 1:length(cue_events)
    trl(k,1) = cue_samples(k) + pre_samples;   % begsample
    trl(k,2) = cue_samples(k) + post_samples;   % endsample
    trl(k,3) = pre_samples;                      % offset（负值表示 cue 前）
    trl(k,4) = cue_events(k).value;              % trigger code
end

% 用 ft_preprocessing 读取眼动通道
cfg_ft = [];
cfg_ft.dataset    = asc_file;
cfg_ft.trl        = trl;
cfg_ft.channel    = {'LX', 'LY', 'RX', 'RY'};  % 根据实际通道名调整
data = ft_preprocessing(cfg_ft);
```

**注意：** `ft_read_event` 对 EyeLink .asc 文件的解析可能需要安装 EyeLink Data Viewer 或配置 FieldTrip 的读取器。如果 `ft_read_event` 无法直接解析 .asc 文件，可能需要：
- 先用 `helper_parse_asc` 提取事件信息，再构建 trl 矩阵
- 或使用 `ft_read_header` + `ft_read_data` 的组合
- 请在实际执行时测试 `ft_read_event` 是否能正确读取 .asc 文件中的 MSG 事件

#### FieldTrip 无法替代的步骤（无论开关如何都保留自定义实现）：

1. **校准归一化** (`compute_calibration_reference`)：FieldTrip 不提供此功能。保留现有逻辑，使用 7 个校准点（trig 201/203-209）的中值注视位置计算 center 和 halfRange，归一化到 ±100%（±5.7°）。
2. **Blink padding** (`expand_nan`)：FieldTrip 不提供自动 blink pad。保留现有逻辑，将 NaN 区域向两侧扩展 ±100 ms。
3. **双眼平均**：将 LX/RX 平均、LY/RY 平均。保留自定义实现。

#### 输出格式兼容性：

无论走哪个分支，输出的 `eye_data` 结构必须保持一致：
```matlab
eye_data.trial      % [ntrl x 2 x ntime]（2 = X 和 Y）
eye_data.trialinfo  % [ntrl x 1] trigger codes
eye_data.time       % [1 x ntime] 时间向量（秒）
eye_data.fsample    % 采样率（1000）
eye_data.sessioninfo % [ntrl x 1] session 编号
eye_data.label      % {'X'; 'Y'}
```

如果 FieldTrip 的 `ft_preprocessing` 输出格式不同（例如 .trial 是 cell array），需要转换为上述格式。

#### 当 `cfg.use_fieldtrip = false` 时：

保持现有逻辑完全不变（使用 `helper_parse_asc` 自定义解析器）。

### 5.3 `r06_group_rate_clusterperm.m` — Cluster Permutation

在"计算群组统计"部分，根据 `cfg.use_fieldtrip` 分支。

#### 当 `cfg.use_fieldtrip = true` 时：

将每个被试的 toward rate 和 away rate 时间序列转换为 FieldTrip 的 `timelock` 结构，然后用 `ft_timelockstatistics` 做配对 cluster permutation：

```matlab
% 构建 toward 数据
data_toward = [];
data_toward.label = {'rate'};
data_toward.time  = {time_vector};      % 1 x Ntime cell
data_toward.dimord = 'rpt_time';
data_toward.trial  = toward_matrix;     % [Nsubj x Ntime]

% 构建 away 数据
data_away = [];
data_away.label = {'rate'};
data_away.time  = {time_vector};
data_away.dimord = 'rpt_time';
data_away.trial  = away_matrix;         % [Nsubj x Ntime]

% 统计配置
stat_cfg = [];
stat_cfg.method           = 'montecarlo';
stat_cfg.statistic        = 'depsamplesT';
stat_cfg.correctm         = 'cluster';
stat_cfg.clusteralpha     = 0.05;
stat_cfg.clusterstatistic = 'maxsum';
stat_cfg.tail             = 0;           % 双尾
stat_cfg.alpha            = 0.05;
stat_cfg.numrandomization = 5000;

% 配对设计矩阵
nSubj = size(data_toward.trial, 1);
stat_cfg.design = [1:nSubj, 1:nSubj; ones(1,nSubj), 2*ones(1,nSubj)];
stat_cfg.ivar = 2;   % 独立变量（条件：1=toward, 2=away）
stat_cfg.uvar = 1;   % 单元变量（被试）

% 执行统计
stat = ft_timelockstatistics(stat_cfg, data_toward, data_away);
```

从 `stat` 结构中提取显著性信息用于绘图：
- `stat.mask`：逻辑向量，标记显著时间点
- `stat.posclusters`：正向聚类信息（含 cluster p-value）
- `stat.negclusters`：负向聚类信息
- 或直接用 `stat.mask` 替代现有 `cluster_result.sigMask` 绘制显著性条

#### 当 `cfg.use_fieldtrip = false` 时：

保持现有逻辑不变（使用 `helper_cluster_perm_1d`）。

#### 绘图代码适配：

需要统一两种模式的输出格式，使绘图代码能从任一模式的结果中提取显著性时间区间。建议：
- 定义统一的 `sig_time_mask` 逻辑向量（与 time_vector 等长）
- FieldTrip 模式：`sig_time_mask = stat.mask`
- 自定义模式：`sig_time_mask = cluster_result.sigMask`
- 绘图代码只使用 `sig_time_mask`

### 5.4 `run_all.m`

1. **移除 r07 步骤**：从 `steps` 列表中删除 `'r07_engbert_kliegl'` 条目
2. **添加 FieldTrip 路径加载**：在 pipeline 开始处，当 `cfg.use_fieldtrip = true` 时，确保调用 `cfg.add_fieldtrip()` 将 FieldTrip 添加到路径

---

## 六、关键约束

1. **不修改原始作者代码**：`code/` 根目录下的 `PBlab_gazepos2shift_1D.m`、`gazeShiftRateOverSize.m`、`get_saccadeEvent.m`、`sortTrial_onSaccade.m`、`get_lateralisation.m`、`creatDir.m`、`get_subFiles.m` 保持原样不动。
2. **不破坏现有功能**：`cfg.use_fieldtrip = false` 时，管线行为必须与修改前完全一致。所有现有 helper 函数保留（除了被删除的 `helper_engbert_kliegl.m`）。
3. **FieldTrip 函数调用前必须确保路径已添加**：使用 `cfg.add_fieldtrip()` 或 `addpath(cfg.fieldtrip_dir, '-begin')`。
4. **数据结构兼容**：无论走哪个分支，输出的数据结构必须与下游脚本兼容。
5. **ft_read_event 对 .asc 文件的兼容性需要测试**：如果 FieldTrip 无法直接读取 .asc 文件中的 MSG 事件，需要使用 `helper_parse_asc` 先提取事件信息，再构建 trl 矩阵传给 `ft_preprocessing`。

---

## 七、验证方案

1. **备份当前输出**：运行前备份 `normalized_eye_data/`、`gaze_shift/`、`results/` 目录
2. **测试 `cfg.use_fieldtrip = false`**：
   - 设置 `cfg.subj = {'s01','s02'}`
   - 运行完整管线 `run_all`
   - 确认输出与备份一致（逐 .mat 文件比较）
3. **测试 `cfg.use_fieldtrip = true`**：
   - 设置 `cfg.subj = {'s01','s02'}`
   - 运行完整管线 `run_all`
   - 确认无报错，所有输出文件正常生成
   - 检查 `results/figures/` 中的图片是否合理
4. **对比两种模式**：
   - 对比 `normalized_eye_data/` 中的 .mat 文件（应完全一致，因为校准/blink/平均逻辑相同）
   - 对比 `results/figures/` 中的图片（应高度相似，cluster permutation 的随机性可能导致微小差异）

---

## 八、执行顺序建议

1. 先修改 `r00_setup.m`（添加开关）
2. 修改 `r01_prepare_eye_data.m`（FieldTrip 数据导入分支）
3. 用 N=2 测试 r01 单独运行
4. 修改 `r06_group_rate_clusterperm.m`（FieldTrip cluster perm 分支）
5. 修改 `run_all.m`（移除 r07 + FieldTrip 路径加载）
6. 删除 `r07_engbert_kliegl.m`、`helper_engbert_kliegl.m` 及其输出文件
7. 运行完整管线验证两种模式（N=2 smoke test）
8. **更新学习文档**（见第九节）

---

## 九、更新学习文档

所有代码修改和验证完成后，需要更新以下 4 个学习文档以对齐最新管线。这些文档位于仓库根目录下。

### 9.1 `asc字段.md` — EyeLink ASC 字段说明

- 移除与 Engbert-Kliegl 相关的说明（如果有）
- 确认 FieldTrip 相关的字段说明（如 `ft_read_event` 对 MSG 行的解析方式）是否需要补充
- 其余内容保持不变

### 9.2 `code代码解释.md` — 代码解释

需要更新的内容：
- **移除** `helper_engbert_kliegl.m` 的说明段落
- **移除** `r07_engbert_kliegl.m` 的说明段落
- **移除** 第三节"原作者代码 vs 复现管线的对应关系"表格中 r07 相关的行
- **新增** `r00_setup.m` 中 `cfg.use_fieldtrip` 开关的说明
- **新增** `r01_prepare_eye_data.m` 中 FieldTrip 数据导入分支的说明
- **新增** `r06_group_rate_clusterperm.m` 中 FieldTrip cluster permutation 分支的说明
- **新增** `run_all.m` 中 FieldTrip 路径加载逻辑的说明
- 更新脚本执行顺序总结（移除 r07，反映新的 run_all 结构）

### 9.3 `学习指导.md` — 学习计划

需要更新的内容：
- **阶段 5（Engbert-Kliegl）整段移除**：该阶段围绕 EK2003 算法展开，已从管线中删除
- **学习深度/实践任务**：在阶段 4 中补充 FieldTrip cluster permutation 的学习内容（`ft_timelockstatistics` 的用法、设计矩阵构建、结果解读）
- **关键术语/算法清单**：移除 Engbert-Kliegl 相关条目，新增 FieldTrip 相关条目（`ft_preprocessing`、`ft_timelockstatistics`、`cfg.use_fieldtrip` 开关机制）
- **风险与依赖**：移除 r07 相关的风险条目，新增 FieldTrip 路径未添加的风险
- **最小可运行路径**：移除 r07 引用
- **管线数据流总览**：移除 Sup Fig 7 相关节点
- **阶段 1 实践任务**：补充 FieldTrip 数据导入分支的学习任务（对比 `cfg.use_fieldtrip = true/false` 两种模式的输出）

### 9.4 `文件梳理.md` — 仓库文件结构

需要更新的内容：
- **目录总览表**：移除 `results/EK_microsaccades_s*.mat`、`results/EK_rate_timecourse.mat`、`results/figures/sup_fig7_EK_rate.png` 的条目
- **代码文件说明**：移除 `r07_engbert_kliegl.m` 和 `helper_engbert_kliegl.m` 的说明段落
- **中间产物与输出文件夹**：移除 `results/` 中 EK 相关文件的说明
- **figures 表格**：移除 `sup_fig7_EK_rate.png` 的条目
- **数据流依赖图**：移除 r07 分支（底部的 `r07_engbert_kliegl` 方框及其输入输出箭头）
- **脚本执行顺序总结**：移除 r07 行
- **新增** `cfg.use_fieldtrip` 开关的说明
- **新增** r01/r06 中 FieldTrip 分支的简要说明
