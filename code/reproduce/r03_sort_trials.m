function r03_sort_trials()
% R03_SORT_TRIALS
% 严格复刻原作者 sortTrial_onSaccade.m 的逻辑，把每个 trial 分成
% toward / away / noMS / tooSmallMS 四类。
%
% 论文 Methods 关键约束：
%   - 时间窗 200-600 ms post-cue
%   - 仅看窗口内"第一个"可分辨眼跳的方向
%   - 幅度 < 1% (= 0.057°) 视为"过小"，不计为 toward/away
%   - 不可用 eye trace（NaN ∈ 0-600 ms post-cue）：单独标记为 unusable
%
% 输出 cfg.out_event/sNN.mat 含:
%   event.sel_toward      [ntrl x 1] logical
%   event.sel_away        [ntrl x 1] logical
%   event.sel_noMS        [ntrl x 1] logical
%   event.sel_tooSmallMS  [ntrl x 1] logical
%   event.sel_unusable    [ntrl x 1] logical  （新增：眨眼/丢失）
%
% 此外计算 Fig 1d 用的"个体比例"并存到 results/。

cfg = r00_setup();

prop = struct('toward',[],'away',[],'noMS',[],'tooSmall',[],'unusable',[]);

for is = 1:numel(cfg.subj)
    subj = cfg.subj{is};
    eye_file   = fullfile(cfg.out_eye,   [subj '.mat']);
    shift_file = fullfile(cfg.out_shift, [subj '.mat']);
    if ~exist(eye_file,'file') || ~exist(shift_file,'file')
        warning('Missing inputs for %s — skip', subj); continue;
    end

    Es = load(eye_file);   eye_data   = Es.eye_data;
    Ss = load(shift_file); data_shift = Ss.data_shift;

    % === 选时间窗 ===
    sel_idx = dsearchn(data_shift.time(:), cfg.sort.t_window(:));
    sel_idx = sel_idx(1):sel_idx(2);
    shift = data_shift.shift;
    shift_raw = shift;                          % 保留原始（含小幅度）副本
    shift(abs(shift) < cfg.sort.shift_min) = 0; % 去掉过小

    shift_tWin     = shift(:, sel_idx);
    shift_tWin_raw = shift_raw(:, sel_idx);
    trialinfo      = data_shift.trialinfo;
    ntrl           = size(shift_tWin,1);

    % === 不可用 trial 检测 (NaN ∈ 0-600 ms post-cue) ===
    % 注意：data_shift.time 由 PBlab 函数裁过头尾，eye_data.time 仍是完整的
    %       但 NaN 检查可以直接用 eye_data 的 X 通道
    t0_idx = dsearchn(eye_data.time(:), 0);
    t1_idx = dsearchn(eye_data.time(:), 0.6);
    Xseg   = squeeze(eye_data.trial(:,1, t0_idx:t1_idx));
    sel_unusable = any(isnan(Xseg), 2);

    % === 三类标签 ===
    toward = false(ntrl,1); away = false(ntrl,1);
    noMS   = false(ntrl,1); tooSmall = false(ntrl,1);

    for k = 1:ntrl
        if sel_unusable(k), continue; end       % 不可用单独标
        a   = shift_tWin(k,:);
        a_r = shift_tWin_raw(k,:);

        idx_shift   = find(a   ~= 0);  % 正常幅度眼跳位置
        idx_smallSh = find(a   ~= a_r); % 被丢弃的小眼跳位置

        if ~isempty(idx_shift)
            trl_ok = true;
            if ~isempty(idx_smallSh)
                trl_ok = idx_shift(1) < idx_smallSh(1);  % 首个是否大眼跳
            end

            if trl_ok
                shiftValue = a(idx_shift(1));
                if ismember(trialinfo(k), cfg.trig.cue_left)
                    if shiftValue < 0, toward(k)=true; else, away(k)=true; end
                elseif ismember(trialinfo(k), cfg.trig.cue_right)
                    if shiftValue < 0, away(k)=true;   else, toward(k)=true; end
                end
            else
                tooSmall(k) = true;
            end
        else
            if ~isempty(idx_smallSh), tooSmall(k) = true;
            else,                     noMS(k)     = true;
            end
        end
    end

    event = struct( ...
        'sel_toward',     toward, ...
        'sel_away',       away, ...
        'sel_noMS',       noMS, ...
        'sel_tooSmallMS', tooSmall, ...
        'sel_unusable',   sel_unusable);

    save(fullfile(cfg.out_event, [subj '.mat']), 'event');

    n = sum(~sel_unusable);   % 可用 trial 数
    prop.toward (is) = sum(toward)   / n;
    prop.away   (is) = sum(away)     / n;
    prop.noMS   (is) = sum(noMS)     / n;
    prop.tooSmall(is)= sum(tooSmall) / n;
    prop.unusable(is)= mean(sel_unusable);

    fprintf('%s: toward=%d (%.1f%%)  away=%d (%.1f%%)  noMS=%d (%.1f%%)  small=%d  unusable=%d\n',...
            subj, sum(toward),100*prop.toward(is), sum(away),100*prop.away(is),...
                  sum(noMS),100*prop.noMS(is), sum(tooSmall), sum(sel_unusable));
end

save(fullfile(cfg.out_results, 'GA_trial_proportions.mat'), 'prop');

% ===== Fig 1d =====
plot_fig1d(prop, cfg);
fprintf('[r03] Done. Trial sorting + Fig 1d.\n');
end


function plot_fig1d(prop, cfg)
% 论文 Fig 1d：堆叠条形图，按 toward 比例排序
[~, ord] = sort(prop.toward, 'descend','MissingPlacement','last');
M = [prop.toward(ord); prop.noMS(ord); prop.away(ord)]';

fig = figure('position',[100 100 600 350], 'Color', 'w');
bar(M, 'stacked'); colormap([0.6 0.85 0.6; 0.6 0.6 0.6; 0.85 0.6 0.85])
ylim([0 1]); ylabel('Proportion of trials'); xlabel('Participants (sorted)')
legend({'Toward','No','Away'}, 'Location','eastoutside')
title(sprintf('Fig 1d | trial-class proportions (N=%d)', sum(~isnan(prop.toward))))

saveas(fig, fullfile(cfg.out_figures, 'fig1d_trial_proportions.png'));
fprintf('  Fig 1d saved.\n');
end
