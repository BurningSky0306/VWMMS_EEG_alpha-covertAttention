# 复现流水线 · Liu, Nobre & van Ede (2022)

> 论文：*Functional but not obligatory link between microsaccades and neural modulation by covert spatial attention*
> 范围：本流水线**只复现眼动相关分析**（Fig 1b/1c/1d/2），跳过 EEG (Fig 3/4)。

## 一键运行

```matlab
cd C:\MATLABEMM\MATLABWorkspaceEMM\VWMMS_EEG_alpha-covertAttention\code\reproduce
run_all
```

仅跑某几步：
```matlab
run_all('only', {'r02','r03'})        % 跳过预处理只做检测+分组
run_all('from', 'r05')                % 从行为统计开始
```

## 文件清单

| # | 文件 | 任务 | 对应论文 | Tier |
|---|---|---|---|---|
| 0 | `r00_setup.m` | 全局配置（路径 / 被试 / trigger） | — | — |
| 1 | `r01_prepare_eye_data.m` | 预处理：解析 .asc → 校准归一化 → 双眼平均 → cue-locked epoch | Methods | 1 |
| 2 | `r02_detect_microsaccades.m` | 调用 `PBlab_gazepos2shift_1D` 做检测，绘 rate × size × time | **Fig 1c** | 1 |
| 3 | `r03_sort_trials.m` | 按 200–600 ms 内首个眼跳分 toward / away / noMS / tooSmall / unusable | **Fig 1d** | 1 |
| 4 | `r04_link_behavior.m` | 行为 log 与 eye trial 对齐 + RT 修剪（>3000 ms + 2.5 SD） | Methods | 2 |
| 5 | `r05_behavior_analysis.m` | error/RT × class 描述统计 + One-way RM-ANOVA + Bonferroni 事后 t + Cohen's d | **Fig 2** | 2/3 |
| 6 | `r06_group_rate_clusterperm.m` | 跨被试 toward/away rate 时间序列 + cluster-based permutation 黑横线（支持 FieldTrip `ft_timelockstatistics`） | **Fig 1b** | 3 |
| ⚙ | `helper_parse_asc.m` | EyeLink ASC 文本解析器 | — | — |
| ⚙ | `helper_cluster_perm_1d.m` | 1D 配对 cluster-based permutation test (Maris & Oostenveld 2007) | — | — |
| ▶ | `run_all.m` | 顺序执行 r01–r06 的总入口（当 `cfg.use_fieldtrip=true` 时预先加载 FieldTrip） | — | — |

## 输出位置

```
VWMMS_EEG_alpha-covertAttention/
├── normalized_eye_data/      ← r01 输出 sNN.mat
├── gaze_shift/               ← r02 输出 sNN.mat
├── event_TAN_mini1/          ← r03 输出 sNN.mat
├── behavior_aligned/         ← r04 输出 sNN.mat
└── results/
    ├── GA_shift_rateAndsize.mat
    ├── GA_trial_proportions.mat
    ├── GA_behavior_stats.mat
    ├── GA_rate_timecourse.mat
    └── figures/
        ├── fig1b_rate_timecourse.png
        ├── fig1c_rate_size_time.png
        ├── fig1d_trial_proportions.png
        └── fig2_behavior.png
```

## 依赖

| 工具 | 用途 | 路径 |
|---|---|---|
| **MATLAB Statistics & ML Toolbox** | `fitrm` / `ranova` / `ttest` | 已装 |
| **ColorBrewer (Stephen23)** | 配色 `brewermap` | 已装；`r02` 自动 fallback 到 parula |
| **FieldTrip** | 当 `cfg.use_fieldtrip=true` 时：r01 用 `ft_redefinetrial` 做 epoching，r06 用 `ft_timelockstatistics` 做 cluster permutation | `C:\MATLABEMM\MATLABAddOnEMM\fieldtrip-20241219` |
| **原作者代码 (`code/`)** | `PBlab_gazepos2shift_1D` / `gazeShiftRateOverSize` 被本流水线直接调用 | 同仓库 |

## 关键设计选择

1. **不修改原作者代码**：原 `code/*.m` 保持不动作为参照；本目录 `reproduce/` 全是新增文件。
2. **FieldTrip 可选集成**：`cfg.use_fieldtrip` 开关控制。`true` 时 r01 用 `ft_redefinetrial` 做 epoching、r06 用 `ft_timelockstatistics` 做 cluster permutation；`false` 时使用自定义实现，行为与修改前完全一致。
3. **校准归一化代码无关**：用 7 个校准点的 X 排序自动识别"左 3 / 中 1 / 右 3"，无需知道 trigger 编码 ↔ 屏幕位置的映射。
4. **小 N 安全网**：`r05` 和 `r06` 在 N<3 时自动降级为纯描述统计，给出警告而非崩溃。当前默认 N=5，不会触发此分支。
5. **Cluster permutation 双实现**：`helper_cluster_perm_1d.m`（自写）和 `ft_timelockstatistics`（FieldTrip），通过 `cfg.use_fieldtrip` 切换。

## 已知限制

- 论文 N=23。本流水线默认 `cfg.subj = {'s01','s02','s03','s04','s06'}` 为 N=5，**推论统计（RM-ANOVA + cluster permutation）可正常运行**。
- 想跑更多被试或 N=22（本地全部被试）：编辑 `r00_setup.m` 中的 `cfg.subj`：
  ```matlab
  % 示例：全部 22 人
  cfg.subj = arrayfun(@(n) sprintf('s%02d',n), [1:4 6 8:25], 'UniformOutput', false);
  ```
  （s05 / s07 在本地不存在，按论文剔除标准排除）

## 与论文的偏离 / 注意事项

- **未做**：EEG alpha 侧化分析（Fig 3、Fig 4），论文 Fig 4 的"早/晚微眼跳 latency 排序"分析。
- **trigger 编码 21–24** 的 cfg 中变量名带 `_en`（编码侧），但实际是 cue 时间锁定（与论文 epoching 一致；变量名沿用原作者）。
- **行为列对齐**：默认假设 .asc cue trigger 数 = 行为 log 行数。若不一致 r04 会按较小者截断并打印警告——出现警告时需手动核查。
- **FieldTrip .asc 兼容性**：`ft_preprocessing` 无法直接读取 .asc 文件（无标准 header），因此 r01 始终用 `helper_parse_asc` 读取原始数据，仅在 epoching 步骤使用 `ft_redefinetrial`。
