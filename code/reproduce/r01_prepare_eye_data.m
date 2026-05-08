function r01_prepare_eye_data()
% R01_PREPARE_EYE_DATA
% 把每个被试的两个 session .asc → 一份 FieldTrip 风格 eye_data.mat
%
% 流程（严格按论文 Methods "Eye-tracking acquisition and pre-processing"）：
%   1. 解析 .asc → 双眼 X/Y + trigger
%   2. 校准归一化：用 7-点校准（trig 201/203/204/205/206/207/209）
%      得到 ±100% = ±5.7° 的归一化坐标
%   3. 双眼平均 → 单 H + 单 V 通道
%   4. 眨眼 NaN 团块向两侧扩 ±100 ms
%   5. cue (trig 21-24) 锁时切 epoch (-1000 ~ +2000 ms)
%   6. 拼接 sess1 + sess2 → 存 normalized_eye_data/sNN.mat
%
% 输出 eye_data 结构兼容原作者代码 (PBlab_gazepos2shift_1D 等):
%   .label    {'X';'Y'}           通道名
%   .fsample  1000                 采样率
%   .time     {1xntrl} 各 trial 的时间向量（通常都相同）
%   .trial    {1xntrl} 每个 cell 是 [2 x ntime] 矩阵
%   .trialinfo [ntrl x 1] cue trigger code
%
% 注：原代码使用 squeeze(eye_data.trial(:,1,:)) 读取——这要求 trial 是
%   3D 数组而非 cell。本函数同时存储两种形式：.trial（cell, FT 标准）和
%   .trialMatrix（3D 数组, 兼容原代码用法）。原 get_saccadeEvent.m 第 24 行
%   用的是 3D 形式，所以我们额外覆盖 .trial 为 3D 数组（牺牲严格 FT 兼容性
%   换取与原代码无缝衔接）。
%
% Reproduce pipeline | 2026

cfg = r00_setup();

for is = 1:numel(cfg.subj)
    subj = cfg.subj{is};
    fprintf('\n=== Preprocessing %s ===\n', subj);

    sess_eye = cell(1,2);
    for sess = 1:2
        % sess2 文件名带 'b' 后缀（s01b_vm.asc）
        if sess == 1, base = subj; else, base = [subj 'b']; end
        asc_file = fullfile(cfg.data_eye{sess}, [base '_vm.asc']);
        if ~exist(asc_file,'file')
            warning('Missing %s — skip session %d', asc_file, sess); continue;
        end
        fprintf('  Parsing %s...\n', asc_file);

        % ---- 读取原始数据 + 事件 ----
        % helper_parse_asc 始终用于获取 gaze 数据（校准归一化需要）
        raw = helper_parse_asc(asc_file);
        cue_mask = ismember(raw.trig_code, [cfg.trig.cue_left, cfg.trig.cue_right]);
        cue_samples_evt = raw.trig_time(cue_mask);
        cue_codes       = raw.trig_code(cue_mask);

        % ---- 校准归一化 ----
        [refX_center, halfRange_X, refY_center, halfRange_Y] = ...
            compute_calibration_reference(raw, cfg);

        % ---- 数据 epoching（FieldTrip 或自定义）----
        use_ft = false;
        if cfg.use_fieldtrip
            cfg.add_fieldtrip();
            % 构建 trl 矩阵：[begsample, endsample, offset, trigger_code]
            pre_n  = round(cfg.epoch_pre  * cfg.Fs);
            post_n = round(cfg.epoch_post * cfg.Fs);
            n_cue  = numel(cue_samples_evt);
            trl = zeros(n_cue, 4);
            for k = 1:n_cue
                [~, smp] = min(abs(raw.t - cue_samples_evt(k)));
                trl(k,1) = smp - pre_n;     % begsample
                trl(k,2) = smp + post_n;    % endsample
                trl(k,3) = -pre_n;          % offset（负值 = cue 前）
                trl(k,4) = cue_codes(k);    % trigger code
            end
            % ft_preprocessing 读取 + epoch 原始数据
            cfg_ft = [];
            cfg_ft.dataset = asc_file;
            cfg_ft.trl     = trl;
            cfg_ft.channel = {'LX', 'LY', 'RX', 'RY'};
            try
                data_ft = ft_preprocessing(cfg_ft);
                use_ft = true;
            catch ME
                warning('ft_preprocessing failed (%s) — falling back to custom epoching', ME.message);
            end
        end

        if use_ft
            % ---- FieldTrip 路径：转换格式 + 校准 + blink ----
            ntrl  = length(data_ft.trial);
            ntime = length(data_ft.time{1});
            trialMat = nan(ntrl, 2, ntime);
            for k = 1:ntrl
                ch = data_ft.trial{k};   % [nchan x ntime]
                if size(ch,1) >= 4
                    avgX = mean(ch(1:2,:), 1, 'omitnan')';  % LX, RX 平均
                    avgY = mean(ch(3:4,:), 1, 'omitnan')';  % LY, RY 平均
                else
                    avgX = ch(1,:)'; avgY = ch(2,:)';
                end
                normX = (avgX - refX_center) / halfRange_X * 100;
                normY = (avgY - refY_center) / halfRange_Y * 100;
                nan_m = isnan(normX) | isnan(normY);
                nan_m = expand_nan(nan_m, round(cfg.blink_pad * cfg.Fs));
                normX(nan_m) = NaN; normY(nan_m) = NaN;
                trialMat(k,1,:) = normX;
                trialMat(k,2,:) = normY;
            end
            time_vec = data_ft.time{1};
            clear data_ft;
        else
            % ---- 自定义路径：helper_parse_asc + 手动 epoch ----
            % 双眼平均
            if raw.binocular
                avgX_all = mean([raw.LX, raw.RX], 2, 'omitnan');
                avgY_all = mean([raw.LY, raw.RY], 2, 'omitnan');
            else
                avgX_all = raw.LX; avgY_all = raw.LY;
            end
            % 归一化
            normX_all = (avgX_all - refX_center) / halfRange_X * 100;
            normY_all = (avgY_all - refY_center) / halfRange_Y * 100;
            % 眨眼 NaN 扩展
            nan_mask = isnan(normX_all) | isnan(normY_all);
            nan_mask = expand_nan(nan_mask, round(cfg.blink_pad * raw.Fs));
            normX_all(nan_mask) = NaN;
            normY_all(nan_mask) = NaN;
            % 时间戳 → 样本 index
            cue_samp_idx = nan(size(cue_samples_evt));
            for k = 1:numel(cue_samples_evt)
                [~, idx] = min(abs(raw.t - cue_samples_evt(k)));
                cue_samp_idx(k) = idx;
            end
            pre_n  = round(cfg.epoch_pre  * raw.Fs);
            post_n = round(cfg.epoch_post * raw.Fs);
            ntime  = pre_n + post_n + 1;
            time_vec = (-pre_n : post_n) / raw.Fs;
            ntrl = numel(cue_samp_idx);
            trialMat = nan(ntrl, 2, ntime);
            keep = true(ntrl,1);
            for k = 1:ntrl
                s0 = cue_samp_idx(k) - pre_n;
                s1 = cue_samp_idx(k) + post_n;
                if s0 < 1 || s1 > numel(normX_all), keep(k) = false; continue; end
                trialMat(k,1,:) = normX_all(s0:s1);
                trialMat(k,2,:) = normY_all(s0:s1);
            end
            trialMat  = trialMat(keep,:,:);
            cue_codes = cue_codes(keep);
        end

        sess_eye{sess}.trialMatrix = trialMat;
        sess_eye{sess}.trialinfo   = cue_codes(:);
        sess_eye{sess}.time        = time_vec;
        sess_eye{sess}.fsample     = cfg.Fs;
        sess_eye{sess}.session     = sess * ones(numel(cue_codes),1);

        fprintf('  Session %d: %d trials extracted\n', sess, numel(cue_codes));
    end

    % ---- 拼接两 session ----
    eye_data = [];
    eye_data.label   = {'X'; 'Y'};
    eye_data.fsample = cfg.Fs;
    eye_data.time    = sess_eye{1}.time;     % 两 session 时间向量相同
    parts_M = {}; parts_TI = {}; parts_S = {};
    for sess = 1:2
        if isempty(sess_eye{sess}), continue; end
        parts_M{end+1}  = sess_eye{sess}.trialMatrix;     %#ok<AGROW>
        parts_TI{end+1} = sess_eye{sess}.trialinfo;       %#ok<AGROW>
        parts_S{end+1}  = sess_eye{sess}.session;         %#ok<AGROW>
    end
    eye_data.trial      = cat(1, parts_M{:});      % [ntrl x 2 x ntime]
    eye_data.trialinfo  = cat(1, parts_TI{:});     % [ntrl x 1]
    eye_data.sessioninfo = cat(1, parts_S{:});     % [ntrl x 1]

    % ---- 保存 ----
    out_file = fullfile(cfg.out_eye, [subj '.mat']);
    save(out_file, 'eye_data');
    fprintf('  Saved %s  (total %d trials)\n', out_file, size(eye_data.trial,1));
end

fprintf('\n[r01] Done. Eye preprocessing for %d subject(s).\n', numel(cfg.subj));
end


% ========================================================================
function [refX_center, halfRange_X, refY_center, halfRange_Y] = ...
    compute_calibration_reference(raw, cfg)
% 用 7 点校准模块计算归一化参考。
% 思路：
%   1. 找到所有 calib trigger（每码 10 次，共 70 个）
%   2. 每次 trigger 后 500-1000 ms 取 (X,Y) 中位数 → 70 个点
%   3. 按 trigger 编码聚合 → 7 个均位
%   4. 按 X 坐标排序：最小 3 个 = 左 / 中 1 个 = 中 / 最大 3 个 = 右
%   5. 同理 Y → 上/中/下
%   6. halfRange_X = 平均(右-中, 中-左)，对应 ±100% = ±5.7°

is_calib = ismember(raw.trig_code, cfg.trig.calib);
calib_times = raw.trig_time(is_calib);
calib_codes = raw.trig_code(is_calib);

if numel(calib_times) < 7
    warning('Only %d calibration triggers found — fallback to display-center reference', ...
            numel(calib_times));
    % fallback: 用屏幕中心 + 假设 1° = ~37 px (95 cm 视距, 24" 1920×1080)
    % 这种情况下需要手动设 halfRange，此处给出一个合理默认避免崩溃
    refX_center = raw.display(1)/2;
    refY_center = raw.display(2)/2;
    halfRange_X = 5.7 * 37;   % 5.7° × ~37 px/° （粗略）
    halfRange_Y = 5.7 * 37;
    return;
end

win_s0 = round(cfg.calib_win(1) * raw.Fs);
win_s1 = round(cfg.calib_win(2) * raw.Fs);

n = numel(calib_times);
medX_each = nan(n,1);
medY_each = nan(n,1);
for k = 1:n
    [~, idx] = min(abs(raw.t - calib_times(k)));
    s0 = idx + win_s0; s1 = idx + win_s1;
    if s0 < 1 || s1 > numel(raw.LX), continue; end
    if raw.binocular
        x_seg = mean([raw.LX(s0:s1), raw.RX(s0:s1)], 2, 'omitnan');
        y_seg = mean([raw.LY(s0:s1), raw.RY(s0:s1)], 2, 'omitnan');
    else
        x_seg = raw.LX(s0:s1); y_seg = raw.LY(s0:s1);
    end
    medX_each(k) = median(x_seg, 'omitnan');
    medY_each(k) = median(y_seg, 'omitnan');
end

% 按编码聚合（每码应有 ~10 次）
codes_uniq = unique(calib_codes);    % 应是 7 个
refX = nan(numel(codes_uniq),1);
refY = nan(numel(codes_uniq),1);
for k = 1:numel(codes_uniq)
    sel = calib_codes == codes_uniq(k);
    refX(k) = median(medX_each(sel), 'omitnan');
    refY(k) = median(medY_each(sel), 'omitnan');
end

% 按 X 排序：3-1-3（左/中/右）
%   left/right 各对应 3 个校准点（与 top/middle/bottom 配对）
%   中心点单独 1 个
[~, ix] = sort(refX);
leftX_mean   = mean(refX(ix(1:3)));
centerX      = refX(ix(4));
rightX_mean  = mean(refX(ix(5:7)));

% 按 Y 排序：2-3-2（上/中/下）
%   top/bottom 各 2 个（left-top + right-top, left-bot + right-bot）
%   middle 是 3 个（left-mid + right-mid + 屏幕中心）
[~, iy] = sort(refY);
% EyeLink 坐标系：Y 向下增大 → 最小 = 上
topY_mean    = mean(refY(iy(1:2)));
centerY      = mean(refY(iy(3:5)));
bottomY_mean = mean(refY(iy(6:7)));

refX_center = centerX;
refY_center = centerY;
halfRange_X = ((rightX_mean - centerX) + (centerX - leftX_mean)) / 2;
halfRange_Y = ((bottomY_mean - centerY) + (centerY - topY_mean)) / 2;

fprintf('  Calibration: center=(%.1f,%.1f) px, halfRange=(%.1f, %.1f) px\n', ...
        centerX, centerY, halfRange_X, halfRange_Y);
end


% ========================================================================
function mask_out = expand_nan(mask_in, pad)
% 把 NaN mask 中的每段 1 向两侧扩 pad 个样本
mask_in = mask_in(:);
edges = diff([0; mask_in; 0]);
starts = find(edges == 1);
ends   = find(edges == -1) - 1;
mask_out = mask_in;
for k = 1:numel(starts)
    s = max(1, starts(k) - pad);
    e = min(numel(mask_in), ends(k) + pad);
    mask_out(s:e) = true;
end
end
