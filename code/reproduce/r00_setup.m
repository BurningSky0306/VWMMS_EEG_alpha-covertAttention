function cfg = r00_setup()
% R00_SETUP  全局路径与参数配置。每个 r0X 脚本最开始都调用一次。
%
% 输出 cfg 结构，包含：
%   .repo_root   仓库根目录
%   .data_eye    eye .asc 数据目录（按 session）
%   .data_log    behavior log 目录（按 session）
%   .out_*       各中间结果输出目录（自动创建）
%   .subj        要分析的被试列表
%   .Fs          采样率
%   .trig        关键 trigger 编码

% ---- 仓库与外部工具路径 ----
cfg.repo_root   = 'C:\MATLABEMM\MATLABWorkspaceEMM\VWMMS_EEG_alpha-covertAttention';
cfg.fieldtrip   = 'C:\MATLABEMM\MATLABAddOnEMM\fieldtrip-20241219';
cfg.use_fieldtrip = true;  % true = 使用 FieldTrip (ft_redefinetrial/ft_timelockstatistics), false = 使用自定义实现
% ColorBrewer 工具包可不在此 addpath（绘图脚本里单独 addpath）

% ---- 输入数据目录 ----
cfg.data_eye = { fullfile(cfg.repo_root,'data','exp1_sess1_eye'), ...
                 fullfile(cfg.repo_root,'data','exp1_sess2_eye') };
cfg.data_log = { fullfile(cfg.repo_root,'data','exp1_sess1_log'), ...
                 fullfile(cfg.repo_root,'data','exp1_sess2_log') };

% ---- 中间产物输出目录（与原作者命名兼容）----
cfg.out_eye      = fullfile(cfg.repo_root, 'normalized_eye_data');     % 预处理后的 eye_data
cfg.out_shift    = fullfile(cfg.repo_root, 'gaze_shift');              % 微眼跳事件
cfg.out_event    = fullfile(cfg.repo_root, 'event_TAN_mini1');         % toward/away/noMS 索引
cfg.out_beh      = fullfile(cfg.repo_root, 'behavior_aligned');        % 与 eye trial 对齐的行为
cfg.out_results  = fullfile(cfg.repo_root, 'results');                 % 跨被试聚合 + 统计
cfg.out_figures  = fullfile(cfg.repo_root, 'results', 'figures');

dirs = {cfg.out_eye, cfg.out_shift, cfg.out_event, cfg.out_beh, cfg.out_results, cfg.out_figures};
for i = 1:numel(dirs)
    if ~exist(dirs{i},'dir'), mkdir(dirs{i}); end
end

% ---- 被试列表 ----
% 论文 N=23（剔除 2 人后），本地有 23 个 .asc。当前用全部 23 人复现。
cfg.subj = arrayfun(@(n) sprintf('s%02d',n), [1:4 6 8:25], 'UniformOutput', false);

% ---- 实验参数 ----
cfg.Fs = 1000;                       % EyeLink 采样率
cfg.epoch_pre  = 1.0;                % cue 前 1 s
cfg.epoch_post = 2.0;                % cue 后 2 s
cfg.blink_pad  = 0.100;              % 眨眼 NaN 向两侧扩 100 ms（论文 Methods）
cfg.calib_win  = [0.500 1.000];      % 校准点 onset 后取 median 的窗口（论文 Methods）

% ---- Trigger 编码 ----
cfg.trig.cue_left  = [21 22];        % cue → 注意左侧记忆项
cfg.trig.cue_right = [23 24];        % cue → 注意右侧记忆项
cfg.trig.calib     = [201 203 204 205 206 207 209];  % 7 个校准点（已验证：每码 10 次）

% ---- 微眼跳检测参数（与论文一致）----
cfg.detect.threshold = 3;            % velocity 阈值 = 3 × median
cfg.detect.smooth_step = 7;          % 7-ms 高斯平滑
cfg.detect.minISI = 100;             % 同一眼跳不重复计数
cfg.detect.winbef = [50 0];
cfg.detect.winaft = [50 100];

% ---- Trial 分类窗口（论文 Methods）----
cfg.sort.t_window     = [0.200 0.600];   % cue 后 200-600 ms
cfg.sort.shift_min    = 1;               % < 1% (= 0.057°) 视为"过小"
% 主分析是否排除 0-600 ms 内含 NaN 的 trial。
% false 更贴近作者公开 sortTrial_onSaccade.m 的实际分类代码；sel_unusable 仍作为 QC 输出。
% 若要严格按 Methods 中 "dismissed prior to classification" 的文字口径做敏感性检查，可改为 true 后重跑 r03-r06。
cfg.sort.exclude_unusable_from_main = false;

% ---- 群组时间序列统计窗口 ----
cfg.stats.rate_wide_window      = [-0.200 1.000];  % 当前复现使用的宽窗口
cfg.stats.numrandomization      = 10000;           % 论文 Methods

% ---- 加 path ----
addpath(fullfile(cfg.repo_root, 'code'));            % 原作者代码
addpath(fullfile(cfg.repo_root, 'code', 'reproduce'));% 我们的复现代码
% FieldTrip 仅在需要时 addpath（避免污染 path），这里给出函数：
cfg.add_fieldtrip = @() add_fieldtrip(cfg.fieldtrip);

end

function add_fieldtrip(ft_path)
    if ~exist(fullfile(ft_path,'ft_defaults.m'),'file')
        warning('FieldTrip not found at %s', ft_path); return;
    end
    addpath(ft_path);
    ft_defaults;
end
