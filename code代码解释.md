# code 文件夹代码解释

---

## 一、`code/` 根目录 -- 原作者代码（Baiwei Liu, 2021）

### 核心算法（2 个）

#### `PBlab_gazepos2shift_1D.m` -- 微眼跳检测核心函数

- 输入：gaze 位置矩阵 `[trials x time]` + 配置参数
- 算法：
  1. 对位置数据求一阶差分得到速度
  2. 7 ms 高斯平滑速度曲线
  3. 计算每条 trial 的速度中位数 x threshold（默认 3）作为阈值
  4. 找到速度超阈的时刻 -> 取该时刻前后窗口内的平均位置差 -> 得到位移量（gaze shift）
  5. 设置 100 ms 的最小间隔（minISI），避免同一眼跳被重复计数
- 输出：shift 矩阵 `[trials x time]`，0 = 无眼跳，非 0 = 位移量（单位与输入相同，归一化后为 %）

#### `gazeShiftRateOverSize.m` -- 按眼跳幅度分箱计算 rate

- 输入：shift 矩阵 + trial 条件信息 + 幅度分箱参数
- 算法：
  1. 按 shift size 分成若干 bin（如 1%-5%, 5%-10%, ...）
  2. 每个 bin 内：将 shift 二值化（有/无）-> 50 ms 移动平均 x 1000 -> 转为 Hz
  3. 分 toward（朝向 cue 方向）和 away（远离 cue 方向）分别计算
- 输出：`rate_size.toward / .away / .diff` 矩阵 `[size_bin x time]`，用于绘制论文 Fig 1c 热力图

### 完整流程脚本（3 个）

#### `get_saccadeEvent.m` -- 微眼跳检测 + Fig 1c 绘图（对应复现管线 r02）

- 硬编码 Mac 路径 `/Users/baiweil/AnalysisDesk/shared_code/`
- 对每个被试：加载归一化 eye_data -> 取 X 通道 -> 调用 `PBlab_gazepos2shift_1D`（threshold=3）
- 跨被试聚合：调用 `gazeShiftRateOverSize` -> 绘制 Fig 1c 三联热力图
- 被复现管线 `r02_detect_microsaccades.m` 替代

#### `sortTrial_onSaccade.m` -- Trial 分类（对应复现管线 r03）

- 硬编码 Mac 路径
- 时间窗 200-600 ms post-cue，取每个 trial 的**第一个**幅度 >= 1 的眼跳
- 根据眼跳方向与 cue 方向的关系分为 toward / away / noMS / tooSmallMS
- 输出：`event_TAN_mini1/sNN.mat`（TAN = Toward/Away/No-microsaccade，mini1 = 第 1 种参数方案）
- 被复现管线 `r03_sort_trials.m` 替代

#### `get_lateralisation.m` -- EEG alpha 侧化分析（对应论文 Fig 3/4，本复现不涉及）

- 硬编码 Mac 路径
- 加载 EEG 时频数据 + trial 分类索引
- 计算 CVSI（Contralateral vs. Ipsilateral Power Index）：`(contra - ipsi) / (contra + ipsi) x 100%`
- 左右半球通道：O1/PO7/PO3/P7/P5/P3/P1 vs O2/PO8/PO4/P8/P6/P4/P2
- 本复现**跳过此脚本**（只复现眼动部分）

### 工具函数（2 个）

#### `creatDir.m` -- 创建目录（如果不存在）

```matlab
function data_out = creatDir(file_dir)
    if ~exist(file_dir,'dir'), mkdir(file_dir); end
    data_out = file_dir;
end
```

#### `get_subFiles.m` -- 列出目录下所有 .mat 文件的完整路径

```matlab
function data_out = get_subFiles(file_dir, varargin)
    % 默认找 *.mat，可选传入其他通配符
    sublist = dir(file_core);
    % 排除以 '.' 开头的隐藏文件
```

### 文档

#### `readme` -- 原作者说明文件

描述代码用途、运行顺序、数据下载链接。

---

## 二、`code/reproduce/` -- 复现管线（按执行顺序）

### r00_setup.m -- 全局配置

所有脚本的"配置中心"，返回一个 `cfg` 结构体，包含：

- 路径：仓库根目录、输入数据目录、各输出目录（自动创建）
- 被试列表：`cfg.subj`（当前设为全部 23 人：`[1:4 6 8:25]`）
- 实验参数：采样率 1000 Hz、epoch 窗口 -1~+2 s、blink padding 100 ms、校准窗口
- Trigger 编码：cue_left=[21 22]、cue_right=[23 24]、calib=[201 203-209]
- 微眼跳检测参数：threshold=3、smooth_step=7、minISI=100
- Trial 分类窗口：200-600 ms post-cue、shift_min=1%
- **`cfg.use_fieldtrip` 开关**：`true` = 使用 FieldTrip（r01 用 ft_redefinetrial 做 epoching，r06 用 ft_timelockstatistics 做 cluster permutation），`false` = 使用自定义实现
- **`cfg.add_fieldtrip` 函数句柄**：将 FieldTrip 目录（`cfg.fieldtrip`）添加到 MATLAB 路径并运行 `ft_defaults`

### r01_prepare_eye_data.m -- 预处理：.asc -> 归一化 eye_data

输入：原始 .asc 文件（两个 session）

处理流程（根据 `cfg.use_fieldtrip` 分支）：

**`cfg.use_fieldtrip = true` 时（FieldTrip 路径）：**
1. 调用 `helper_parse_asc` 解析 .asc 获取原始 gaze 数据（.asc 非 FieldTrip 原生格式，无法用 `ft_preprocessing` 直接读取，需用 helper_parse_asc 先解析）
2. 双眼平均 + 校准归一化 + blink padding（在连续数据上完成）
3. 构建 FieldTrip 连续数据结构，用 `ft_redefinetrial` 基于 cue 事件的 trl 矩阵做 epoching
4. 转换 FieldTrip cell array 格式为 3D 矩阵

**`cfg.use_fieldtrip = false` 时（自定义路径，与修改前完全一致）：**
1. 调用 `helper_parse_asc` 解析 .asc -> 双眼 X/Y + trigger
2. 校准归一化：用 7 个校准点（trig 201/203-209）的 X 排序自动识别"左 3 / 中 1 / 右 3"，计算 center 和 halfRange，将像素坐标转换为 +/-100%（对应 +/-5.7 度）
3. 双眼平均 -> 单 X + 单 Y 通道
4. 眨眼 NaN 团块向两侧扩 +/-100 ms
5. Cue (trig 21-24) 锁时切 epoch（-1000 ~ +2000 ms）

两种路径都执行：拼接 session 1 + session 2

输出：`normalized_eye_data/sNN.mat`（`eye_data.trial [ntrl x 2 x ntime]`、`.trialinfo`、`.time`）

注：FieldTrip 的 `ft_preprocessing` 无法直接读取 .asc 文件（无标准 header），因此 r01 始终用 `helper_parse_asc` 读取数据，仅在 epoching 步骤使用 `ft_redefinetrial`。

### r02_detect_microsaccades.m -- 微眼跳检测 + Fig 1c

输入：`normalized_eye_data/sNN.mat`

处理流程：

1. 取 X 通道 -> 调用原作者的 `PBlab_gazepos2shift_1D`（threshold=3 x median）
2. 调用 `gazeShiftRateOverSize` 计算 rate x size x time 矩阵
3. 跨被试聚合为 `GA_struct`（toward/away/diff）
4. 绘制 Fig 1c 三联热力图

输出：`gaze_shift/sNN.mat`、`results/GA_shift_rateAndsize.mat`、`results/figures/fig1c_rate_size_time.png`

### r03_sort_trials.m -- Trial 分类 + Fig 1d

输入：`normalized_eye_data/sNN.mat` + `gaze_shift/sNN.mat`

处理流程：

1. 在 200-600 ms post-cue 窗口内，取每个 trial 的**第一个**幅度 >= 1% 的眼跳
2. 根据眼跳方向与 cue 方向分为 toward / away / noMS / tooSmallMS / unusable（NaN 在 0-600 ms 内的 trial）
3. 计算每个被试的各条件比例
4. 绘制 Fig 1d 堆叠条形图（按 toward 比例排序）

输出：`event_TAN_mini1/sNN.mat`、`results/GA_trial_proportions.mat`、`results/figures/fig1d_trial_proportions.png`

### r04_link_behavior.m -- 行为对齐

输入：行为 .txt log + `normalized_eye_data/sNN.mat`

处理流程：

1. 读取两 session 的行为 log（Presentation 输出的 .txt），拼接
2. 与 eye trial 逐行对齐（若行数不一致则按较小者截断）
3. 提取关键列：targetLoc、RT1（cue -> response onset）、reportVsTarget
4. 计算 error = |reportVsTarget|
5. RT 修剪：>3000 ms 剔除 + 2.5 SD 截断

输出：`behavior_aligned/sNN.mat`（behavior 表，含 RT、error、valid_RT 等列）

### r05_behavior_analysis.m -- 行为统计 + Fig 2

输入：`behavior_aligned/sNN.mat` + `event_TAN_mini1/sNN.mat`

处理流程：

1. 对每个被试，按 toward/no/away 三条件计算 mean error 和 mean RT
2. 归一化：(val - mean_subj) / mean_subj x 100%
3. One-way Repeated-Measures ANOVA + Bonferroni 事后配对 t 检验 + Cohen's d
4. N<3 时自动降级为纯描述统计（跳过推断）；当前默认 N=5，推论统计正常执行
5. 绘制 Fig 2（上排：原始均值 +/- SEM + 被试连线；下排：归一化散点）

输出：`results/GA_behavior_stats.mat`、`results/figures/fig2_behavior.png`

### r06_group_rate_clusterperm.m -- 跨被试 rate + cluster perm + Fig 1b

输入：`gaze_shift/sNN.mat`

处理流程（根据 `cfg.use_fieldtrip` 分支）：

1. 对每个被试：将 shift 矩阵二值化 -> 50 ms 移动平均 x 1000 -> 转为 Hz（toward/away 分别计算）
2. 截取 [-0.2, 1] s 窗口
3. **`cfg.use_fieldtrip = true` 时**：将 toward/away 数据转为 FieldTrip `timelock` 结构，用 `ft_timelockstatistics` 做配对 cluster permutation（depsamplesT, 5000 次随机化），从 `stat.mask` 提取显著时间点
4. **`cfg.use_fieldtrip = false` 时**：调用 `helper_cluster_perm_1d` 做配对 cluster-based permutation test
5. 绘制 Fig 1b：toward/away rate 时间序列 + 95% CI 阴影 + 显著性黑横线

输出：`results/GA_rate_timecourse.mat`、`results/figures/fig1b_rate_timecourse.png`

### helper_parse_asc.m -- EyeLink ASC 解析器

输入：.asc 文件路径

处理：逐行解析 EyeLink ASC 文本，提取双眼 gaze 样本（LX/LY/RX/RY）、trigger（MSG trig 行）、采样率、屏幕分辨率；自动检测单/双眼记录；将缺失值 `.` 转 NaN

输出：`out` 结构（.Fs、.t、.LX/.LY/.RX/.RY、.trig_code/.trig_time、.display、.binocular）

### helper_cluster_perm_1d.m -- 1D Cluster Permutation 检验

输入：A、B 两个 `[N_subjects x N_timepoints]` 配对矩阵

算法（Maris & Oostenveld, 2007）：

1. 配对差 -> 逐时间点 t 值
2. 超阈值（|t| >= t_crit）的相邻同号点聚成 cluster -> 计算 t-mass
3. 随机翻转符号 N 次（默认 10000）-> 每次取最大 cluster mass -> 构建零分布
4. 每个原始 cluster 的 p = 零分布中 >= 该 cluster mass 的比例

输出：`out.clusters`（含 start/stop/mass/p）、`.sigMask`、`.tvals`

### run_all.m -- 管线总入口

- 顺序执行 r01 -> r02 -> r03 -> r04 -> r05 -> r06
- 支持 `run_all('from','r03')` 从某步开始，或 `run_all('only',{'r02','r03'})` 只跑指定步骤
- 当 `cfg.use_fieldtrip = true` 时，在管线开始前调用 `cfg.add_fieldtrip()` 加载 FieldTrip 路径
- 计时并打印总耗时

### README.md -- 复现管线说明文档

---

## 三、原作者代码 vs 复现管线的对应关系

| 原作者脚本 | 复现管线 | 改进点 |
|---|---|---|
| `get_saccadeEvent.m` | `r02_detect_microsaccades.m` | 去掉 Mac 硬编码路径，改用 `r00_setup` 配置 |
| `sortTrial_onSaccade.m` | `r03_sort_trials.m` | 同上 + 新增 unusable 标签（NaN 在关键窗口内） |
| `get_lateralisation.m` | 不复现 | 跳过 EEG 部分 |
| -- | `r01_prepare_eye_data.m` | 新增，原作者假设 eye_data 已由 FieldTrip 预处理；支持 `cfg.use_fieldtrip` 切换 FieldTrip/自定义导入 |
| -- | `r04_link_behavior.m` | 新增，原作者未包含行为对齐代码 |
| -- | `r05_behavior_analysis.m` | 新增，原作者未包含行为统计代码 |
| -- | `r06_group_rate_clusterperm.m` | 新增，原作者未做 cluster permutation；支持 `cfg.use_fieldtrip` 切换 ft_timelockstatistics/自定义实现 |
