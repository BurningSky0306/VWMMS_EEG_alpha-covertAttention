function r03_sort_trials()
% R03_SORT_TRIALS
% Sort trials into toward / away / noMS / tooSmallMS based on the first
% detected gaze shift in the 200-600 ms post-cue window.
%
% The core direction logic intentionally mirrors the released
% sortTrial_onSaccade.m code:
%   1. Set abs(shift) < 1% to zero.
%   2. Find the first non-zero shift in the selection window.
%   3. If a discarded small shift preceded it, mark the trial tooSmallMS.
%   4. Otherwise classify the first remaining shift relative to cue side.
%
% We additionally keep a QC field, sel_unusable, for trials whose horizontal
% eye trace contains NaN in 0-600 ms post-cue. Whether this QC mask is applied
% to the main labels is controlled centrally by
% cfg.sort.exclude_unusable_from_main and is saved in event.sort_config.

cfg = r00_setup();
exclude_unusable = cfg.sort.exclude_unusable_from_main;

prop = struct( ...
    'toward',[],'away',[],'noMS',[],'tooSmall',[],'unusable',[], ...
    'all_toward',[],'all_away',[],'all_noMS',[],'all_tooSmall',[], ...
    'n_main',[],'n_threeclass',[],'n_total',[],'n_unclassified',[], ...
    'exclude_unusable_from_main', exclude_unusable);

for is = 1:numel(cfg.subj)
    subj = cfg.subj{is};
    eye_file   = fullfile(cfg.out_eye,   [subj '.mat']);
    shift_file = fullfile(cfg.out_shift, [subj '.mat']);
    if ~exist(eye_file,'file') || ~exist(shift_file,'file')
        warning('Missing inputs for %s -- skip', subj);
        continue;
    end

    Es = load(eye_file);   eye_data   = Es.eye_data;
    Ss = load(shift_file); data_shift = Ss.data_shift;

    sel_idx = dsearchn(data_shift.time(:), cfg.sort.t_window(:));
    sel_idx = sel_idx(1):sel_idx(2);

    shift = data_shift.shift;
    shift_raw = shift;
    shift(abs(shift) < cfg.sort.shift_min) = 0;

    shift_tWin     = shift(:, sel_idx);
    shift_tWin_raw = shift_raw(:, sel_idx);
    trialinfo      = data_shift.trialinfo;
    ntrl           = size(shift_tWin,1);

    sel_unusable = detect_unusable_trials(eye_data);
    [toward_core, away_core, noMS_core, tooSmall_core] = ...
        classify_author_style(shift_tWin, shift_tWin_raw, trialinfo, cfg);

    if exclude_unusable
        sel_main = ~sel_unusable;
    else
        sel_main = true(ntrl,1);
    end

    toward  = toward_core  & sel_main;
    away    = away_core    & sel_main;
    noMS    = noMS_core    & sel_main;
    tooSmall= tooSmall_core& sel_main;
    unclassified = sel_main & ~(toward | away | noMS | tooSmall);

    if any(unclassified)
        warning('%s: %d main-analysis trials were not classified.', subj, sum(unclassified));
    end

    event = struct( ...
        'sel_toward',          toward, ...
        'sel_away',            away, ...
        'sel_noMS',            noMS, ...
        'sel_tooSmallMS',      tooSmall, ...
        'sel_unusable',        sel_unusable, ...
        'sel_main',            sel_main, ...
        'sel_unclassified',    unclassified, ...
        'sel_toward_core',     toward_core, ...
        'sel_away_core',       away_core, ...
        'sel_noMS_core',       noMS_core, ...
        'sel_tooSmallMS_core', tooSmall_core, ...
        'sort_config',         struct( ...
            't_window', cfg.sort.t_window, ...
            'shift_min', cfg.sort.shift_min, ...
            'exclude_unusable_from_main', exclude_unusable));

    save(fullfile(cfg.out_event, [subj '.mat']), 'event');

    n_main  = sum(sel_main);
    n_three = sum(toward | away | noMS);
    if n_three == 0
        warning('%s: no toward/away/noMS trials after sorting.', subj);
        n_three = NaN;
    end

    % Paper-comparable Fig 1d proportions: only toward/noMS/away are stacked.
    prop.toward(is)  = sum(toward) / n_three;
    prop.away(is)    = sum(away)   / n_three;
    prop.noMS(is)    = sum(noMS)   / n_three;

    % QC fractions use the main-analysis denominator and all-trial denominator.
    prop.tooSmall(is)= sum(tooSmall) / n_main;
    prop.unusable(is)= mean(sel_unusable);
    prop.all_toward(is)   = sum(toward_core)   / ntrl;
    prop.all_away(is)     = sum(away_core)     / ntrl;
    prop.all_noMS(is)     = sum(noMS_core)     / ntrl;
    prop.all_tooSmall(is) = sum(tooSmall_core) / ntrl;
    prop.n_main(is)       = n_main;
    prop.n_threeclass(is) = sum(toward | away | noMS);
    prop.n_total(is)      = ntrl;
    prop.n_unclassified(is) = sum(unclassified);

    fprintf(['%s: T=%d A=%d N=%d small=%d unusable=%d | ' ...
             'Fig1d norm T=%.1f%% A=%.1f%% N=%.1f%% | exclude_unusable=%d\n'], ...
            subj, sum(toward), sum(away), sum(noMS), sum(tooSmall), sum(sel_unusable), ...
            100*prop.toward(is), 100*prop.away(is), 100*prop.noMS(is), exclude_unusable);
end

save(fullfile(cfg.out_results, 'GA_trial_proportions.mat'), 'prop');

plot_fig1d(prop, cfg);
fprintf('[r03] Done. Trial sorting + Fig 1d.\n');
end


function sel_unusable = detect_unusable_trials(eye_data)
% Mark trials with any NaN in the horizontal trace from 0 to 600 ms post-cue.
t0_idx = dsearchn(eye_data.time(:), 0);
t1_idx = dsearchn(eye_data.time(:), 0.6);
Xseg = squeeze(eye_data.trial(:,1, t0_idx:t1_idx));
sel_unusable = any(isnan(Xseg), 2);
end


function [toward, away, noMS, tooSmall] = classify_author_style(shift_tWin, shift_tWin_raw, trialinfo, cfg)
% Mirror the released sortTrial_onSaccade.m trial loop as closely as possible.
ntrl = size(shift_tWin,1);
toward = false(ntrl,1);
away = false(ntrl,1);
noMS = false(ntrl,1);
tooSmall = false(ntrl,1);

for k = 1:ntrl
    dataInTrl = shift_tWin(k,:);
    dataInTrl_raw = shift_tWin_raw(k,:);

    shiftInd = find(dataInTrl ~= 0);
    tooSmallSaccInd = find(dataInTrl ~= dataInTrl_raw);

    if ~isempty(shiftInd)
        trl_ok = true;
        if ~isempty(tooSmallSaccInd)
            trl_ok = shiftInd(1) < tooSmallSaccInd(1);
        end

        if trl_ok
            shiftValue = dataInTrl(shiftInd(1));
            if ismember(trialinfo(k), cfg.trig.cue_left)
                if shiftValue < 0
                    toward(k) = true;
                else
                    away(k) = true;
                end
            elseif ismember(trialinfo(k), cfg.trig.cue_right)
                if shiftValue < 0
                    away(k) = true;
                else
                    toward(k) = true;
                end
            end
        else
            tooSmall(k) = true;
        end
    else
        if ~isempty(tooSmallSaccInd)
            tooSmall(k) = true;
        else
            noMS(k) = true;
        end
    end
end
end


function plot_fig1d(prop, cfg)
% Paper-style Fig 1d: stacked toward/noMS/away proportions sum to one.
[~, ord] = sort(prop.toward, 'descend','MissingPlacement','last');
M = [prop.toward(ord); prop.noMS(ord); prop.away(ord)]';

fig = figure('position',[100 100 620 350], 'Color', 'w');
bar(M, 'stacked');
colormap([0.6 0.85 0.6; 0.6 0.6 0.6; 0.85 0.6 0.85])
ylim([0 1]); ylabel('Proportion of toward/no/away trials'); xlabel('Participants (sorted)')
legend({'Toward','No','Away'}, 'Location','eastoutside')
title(sprintf('Fig 1d | paper-comparable classes (N=%d, exclude unusable=%d)', ...
      sum(~isnan(prop.toward)), cfg.sort.exclude_unusable_from_main))

saveas(fig, fullfile(cfg.out_figures, 'fig1d_trial_proportions.png'));
fprintf('  Fig 1d saved.\n');
end
