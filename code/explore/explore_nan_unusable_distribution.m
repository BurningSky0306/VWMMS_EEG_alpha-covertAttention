function nan_diag = explore_nan_unusable_distribution(cfg, out_dir)
% EXPLORE_NAN_UNUSABLE_DISTRIBUTION
% Read-only diagnostic for NaN/unusable trial propagation in the current
% reproduction outputs. Writes only under results/exploration.

if nargin < 1 || isempty(cfg)
    cfg = r00_setup();
end
if nargin < 2 || isempty(out_dir)
    out_dir = fullfile(cfg.out_results, 'exploration');
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

cond_names = {'toward','no','away'};
cond_fields = {'sel_toward','sel_noMS','sel_away'};
class_names = {'toward','noMS','away','tooSmall','unclassified'};
class_fields = {'sel_toward','sel_noMS','sel_away','sel_tooSmallMS','sel_unclassified'};

nS = numel(cfg.subj);
n_cond = numel(cond_names);

err_keep = nan(nS, n_cond);
rt_keep = nan(nS, n_cond);
n_keep = nan(nS, n_cond);
err_excl = nan(nS, n_cond);
rt_excl = nan(nS, n_cond);
n_excl = nan(nS, n_cond);

subj_col = {};
trial_col = [];
session_col = [];
cue_col = {};
class_col = {};
valid_col = [];
unusable_col = [];
nan_x_col = [];
nan_y_col = [];
nan_xy_col = [];
nan_x_sel_col = [];
too_small_col = [];
unclassified_col = [];
rt_col = [];
err_col = [];

summary_subject = {};
summary_total = [];
summary_sess1 = [];
summary_sess2 = [];
summary_valid_rt = [];
summary_invalid_rt = [];
summary_unusable = [];
summary_unusable_rate = [];
summary_nan_x_mismatch = [];
summary_nan_y_only = [];
summary_toward = [];
summary_no = [];
summary_away = [];
summary_too_small = [];
summary_unclassified = [];
summary_unusable_toward = [];
summary_unusable_no = [];
summary_unusable_away = [];
summary_unusable_too_small = [];
summary_invalid_toward = [];
summary_invalid_no = [];
summary_invalid_away = [];

break_subject = {};
break_session = [];
break_class = {};
break_cue = {};
break_rt_group = {};
break_n = [];
break_unusable = [];
break_unusable_rate = [];
break_mean_error = [];
break_mean_rt = [];

for is = 1:nS
    subj = cfg.subj{is};
    eye_file = fullfile(cfg.out_eye, [subj '.mat']);
    event_file = fullfile(cfg.out_event, [subj '.mat']);
    beh_file = fullfile(cfg.out_beh, [subj '.mat']);

    require_file(eye_file);
    require_file(event_file);
    require_file(beh_file);

    Eye = load(eye_file);
    E = load(event_file);
    B = load(beh_file);
    eye_data = Eye.eye_data;
    ev = E.event;
    behavior = B.behavior;

    ntrl = height(behavior);
    assert(numel(ev.sel_toward) == ntrl, '%s: event/behavior length mismatch.', subj);
    assert(size(eye_data.trial, 1) == ntrl, '%s: eye/behavior length mismatch.', subj);

    u = logical(ev.sel_unusable(:));
    valid_rt = logical(behavior.valid_RT(:));
    session = behavior.session(:);
    rt = behavior.RT(:);
    er = behavior.error(:);
    cue_labels = cue_side_labels(eye_data.trialinfo(:), cfg);
    trial_class = get_trial_class(ev, ntrl);

    [nan_x_0_600, nan_y_0_600, nan_xy_0_600, nan_x_200_600] = ...
        compute_nan_masks(eye_data);

    too_small = logical(ev.sel_tooSmallMS(:));
    unclassified = get_event_mask(ev, 'sel_unclassified', ntrl);

    subj_col = [subj_col; repmat({subj}, ntrl, 1)]; %#ok<AGROW>
    trial_col = [trial_col; (1:ntrl)']; %#ok<AGROW>
    session_col = [session_col; session]; %#ok<AGROW>
    cue_col = [cue_col; cue_labels]; %#ok<AGROW>
    class_col = [class_col; trial_class]; %#ok<AGROW>
    valid_col = [valid_col; valid_rt]; %#ok<AGROW>
    unusable_col = [unusable_col; u]; %#ok<AGROW>
    nan_x_col = [nan_x_col; nan_x_0_600]; %#ok<AGROW>
    nan_y_col = [nan_y_col; nan_y_0_600]; %#ok<AGROW>
    nan_xy_col = [nan_xy_col; nan_xy_0_600]; %#ok<AGROW>
    nan_x_sel_col = [nan_x_sel_col; nan_x_200_600]; %#ok<AGROW>
    too_small_col = [too_small_col; too_small]; %#ok<AGROW>
    unclassified_col = [unclassified_col; unclassified]; %#ok<AGROW>
    rt_col = [rt_col; rt]; %#ok<AGROW>
    err_col = [err_col; er]; %#ok<AGROW>

    summary_subject{end+1,1} = subj; %#ok<AGROW>
    summary_total(end+1,1) = ntrl; %#ok<AGROW>
    summary_sess1(end+1,1) = sum(session == 1); %#ok<AGROW>
    summary_sess2(end+1,1) = sum(session == 2); %#ok<AGROW>
    summary_valid_rt(end+1,1) = sum(valid_rt); %#ok<AGROW>
    summary_invalid_rt(end+1,1) = sum(~valid_rt); %#ok<AGROW>
    summary_unusable(end+1,1) = sum(u); %#ok<AGROW>
    summary_unusable_rate(end+1,1) = safe_rate(sum(u), ntrl); %#ok<AGROW>
    summary_nan_x_mismatch(end+1,1) = sum(u ~= nan_x_0_600); %#ok<AGROW>
    summary_nan_y_only(end+1,1) = sum(nan_y_0_600 & ~nan_x_0_600); %#ok<AGROW>
    summary_toward(end+1,1) = sum(logical(ev.sel_toward(:))); %#ok<AGROW>
    summary_no(end+1,1) = sum(logical(ev.sel_noMS(:))); %#ok<AGROW>
    summary_away(end+1,1) = sum(logical(ev.sel_away(:))); %#ok<AGROW>
    summary_too_small(end+1,1) = sum(too_small); %#ok<AGROW>
    summary_unclassified(end+1,1) = sum(unclassified); %#ok<AGROW>
    summary_unusable_toward(end+1,1) = sum(u & logical(ev.sel_toward(:))); %#ok<AGROW>
    summary_unusable_no(end+1,1) = sum(u & logical(ev.sel_noMS(:))); %#ok<AGROW>
    summary_unusable_away(end+1,1) = sum(u & logical(ev.sel_away(:))); %#ok<AGROW>
    summary_unusable_too_small(end+1,1) = sum(u & too_small); %#ok<AGROW>
    summary_invalid_toward(end+1,1) = sum(~valid_rt & logical(ev.sel_toward(:))); %#ok<AGROW>
    summary_invalid_no(end+1,1) = sum(~valid_rt & logical(ev.sel_noMS(:))); %#ok<AGROW>
    summary_invalid_away(end+1,1) = sum(~valid_rt & logical(ev.sel_away(:))); %#ok<AGROW>

    for ik = 1:n_cond
        m = logical(ev.(cond_fields{ik})(:)) & valid_rt;
        mex = m & ~u;
        err_keep(is,ik) = safe_mean(er(m));
        rt_keep(is,ik) = safe_mean(rt(m));
        n_keep(is,ik) = sum(m);
        err_excl(is,ik) = safe_mean(er(mex));
        rt_excl(is,ik) = safe_mean(rt(mex));
        n_excl(is,ik) = sum(mex);
    end

    cue_groups = {'left','right','other'};
    rt_groups = {'validRT','trimmedRT'};
    for ss = 1:2
        for ic = 1:numel(class_names)
            class_mask = get_event_mask(ev, class_fields{ic}, ntrl);
            for ig = 1:numel(cue_groups)
                cue_mask = strcmp(cue_labels, cue_groups{ig});
                for ir = 1:numel(rt_groups)
                    if ir == 1
                        rt_mask = valid_rt;
                    else
                        rt_mask = ~valid_rt;
                    end
                    m = session == ss & class_mask & cue_mask & rt_mask;
                    break_subject{end+1,1} = subj; %#ok<AGROW>
                    break_session(end+1,1) = ss; %#ok<AGROW>
                    break_class{end+1,1} = class_names{ic}; %#ok<AGROW>
                    break_cue{end+1,1} = cue_groups{ig}; %#ok<AGROW>
                    break_rt_group{end+1,1} = rt_groups{ir}; %#ok<AGROW>
                    break_n(end+1,1) = sum(m); %#ok<AGROW>
                    break_unusable(end+1,1) = sum(m & u); %#ok<AGROW>
                    break_unusable_rate(end+1,1) = safe_rate(sum(m & u), sum(m)); %#ok<AGROW>
                    break_mean_error(end+1,1) = safe_mean(er(m)); %#ok<AGROW>
                    break_mean_rt(end+1,1) = safe_mean(rt(m)); %#ok<AGROW>
                end
            end
        end
    end
end

trial_flags = table(subj_col, trial_col, session_col, cue_col, class_col, ...
    valid_col, unusable_col, nan_x_col, nan_y_col, nan_xy_col, ...
    nan_x_sel_col, too_small_col, unclassified_col, rt_col, err_col, ...
    'VariableNames', {'subject','trial_index','session','cue_side','class_name', ...
    'valid_RT','sel_unusable','nan_x_0_600','nan_y_0_600','nan_xy_0_600', ...
    'nan_x_200_600','sel_tooSmallMS','sel_unclassified','RT','error'});

subject_summary = table(summary_subject, summary_total, summary_sess1, summary_sess2, ...
    summary_valid_rt, summary_invalid_rt, summary_unusable, summary_unusable_rate, ...
    summary_nan_x_mismatch, summary_nan_y_only, summary_toward, summary_no, ...
    summary_away, summary_too_small, summary_unclassified, summary_unusable_toward, ...
    summary_unusable_no, summary_unusable_away, summary_unusable_too_small, ...
    summary_invalid_toward, summary_invalid_no, summary_invalid_away, ...
    'VariableNames', {'subject','n_total','n_session1','n_session2','n_valid_RT', ...
    'n_trimmed_RT','n_unusable','unusable_rate','n_event_vs_nanx_mismatch', ...
    'n_nan_y_only_0_600','n_toward','n_noMS','n_away','n_tooSmall', ...
    'n_unclassified','n_unusable_toward','n_unusable_noMS','n_unusable_away', ...
    'n_unusable_tooSmall','n_trimmed_toward','n_trimmed_noMS','n_trimmed_away'});

breakdown = table(break_subject, break_session, break_class, break_cue, break_rt_group, ...
    break_n, break_unusable, break_unusable_rate, break_mean_error, break_mean_rt, ...
    'VariableNames', {'subject','session','class_name','cue_side','rt_group', ...
    'n_trials','n_unusable','unusable_rate','mean_error','mean_RT'});

condition_sensitivity = build_condition_sensitivity(cfg.subj, cond_names, ...
    err_keep, rt_keep, n_keep, err_excl, rt_excl, n_excl);

[group_sensitivity, contrast_sensitivity] = build_group_sensitivity(cond_names, ...
    err_keep, rt_keep, n_keep, err_excl, rt_excl, n_excl);

global_class_counts = build_global_class_counts(trial_flags, class_names);
global_session_counts = build_global_session_counts(trial_flags);

matrices = struct();
matrices.err_keep = err_keep;
matrices.rt_keep = rt_keep;
matrices.n_keep = n_keep;
matrices.err_exclude_unusable = err_excl;
matrices.rt_exclude_unusable = rt_excl;
matrices.n_exclude_unusable = n_excl;

nan_diag = struct();
nan_diag.subject_summary = subject_summary;
nan_diag.breakdown = breakdown;
nan_diag.trial_flags = trial_flags;
nan_diag.condition_sensitivity = condition_sensitivity;
nan_diag.group_sensitivity = group_sensitivity;
nan_diag.contrast_sensitivity = contrast_sensitivity;
nan_diag.global_class_counts = global_class_counts;
nan_diag.global_session_counts = global_session_counts;
nan_diag.matrices = matrices;

nan_diag.paths = struct();
nan_diag.paths.mat = fullfile(out_dir, 'nan_unusable_distribution.mat');
nan_diag.paths.subject_summary_csv = fullfile(out_dir, 'nan_unusable_subject_summary.csv');
nan_diag.paths.breakdown_csv = fullfile(out_dir, 'nan_unusable_breakdown.csv');
nan_diag.paths.trial_flags_csv = fullfile(out_dir, 'nan_unusable_trial_flags.csv');
nan_diag.paths.condition_sensitivity_csv = fullfile(out_dir, 'nan_unusable_condition_sensitivity.csv');
nan_diag.paths.group_sensitivity_csv = fullfile(out_dir, 'nan_unusable_group_sensitivity.csv');
nan_diag.paths.contrast_sensitivity_csv = fullfile(out_dir, 'nan_unusable_contrast_sensitivity.csv');
nan_diag.paths.global_class_counts_csv = fullfile(out_dir, 'nan_unusable_global_class_counts.csv');
nan_diag.paths.global_session_counts_csv = fullfile(out_dir, 'nan_unusable_global_session_counts.csv');

save(nan_diag.paths.mat, 'nan_diag');
writetable(subject_summary, nan_diag.paths.subject_summary_csv);
writetable(breakdown, nan_diag.paths.breakdown_csv);
writetable(trial_flags, nan_diag.paths.trial_flags_csv);
writetable(condition_sensitivity, nan_diag.paths.condition_sensitivity_csv);
writetable(group_sensitivity, nan_diag.paths.group_sensitivity_csv);
writetable(contrast_sensitivity, nan_diag.paths.contrast_sensitivity_csv);
writetable(global_class_counts, nan_diag.paths.global_class_counts_csv);
writetable(global_session_counts, nan_diag.paths.global_session_counts_csv);

fprintf('[explore] NaN/unusable diagnostic saved under %s\n', out_dir);
end

function require_file(path_in)
if ~exist(path_in, 'file')
    error('Required file not found: %s', path_in);
end
end

function [nan_x_0_600, nan_y_0_600, nan_xy_0_600, nan_x_200_600] = compute_nan_masks(eye_data)
t0 = dsearchn(eye_data.time(:), 0);
t1 = dsearchn(eye_data.time(:), 0.6);
t_sel0 = dsearchn(eye_data.time(:), 0.2);
X0 = squeeze(eye_data.trial(:,1,t0:t1));
Y0 = squeeze(eye_data.trial(:,2,t0:t1));
Xsel = squeeze(eye_data.trial(:,1,t_sel0:t1));
nan_x_0_600 = any(isnan(X0), 2);
nan_y_0_600 = any(isnan(Y0), 2);
nan_xy_0_600 = nan_x_0_600 | nan_y_0_600;
nan_x_200_600 = any(isnan(Xsel), 2);
end

function labels = cue_side_labels(trialinfo, cfg)
labels = repmat({'other'}, numel(trialinfo), 1);
labels(ismember(trialinfo, cfg.trig.cue_left)) = {'left'};
labels(ismember(trialinfo, cfg.trig.cue_right)) = {'right'};
end

function labels = get_trial_class(ev, ntrl)
labels = repmat({'unclassified'}, ntrl, 1);
labels(logical(ev.sel_toward(:))) = {'toward'};
labels(logical(ev.sel_noMS(:))) = {'noMS'};
labels(logical(ev.sel_away(:))) = {'away'};
labels(logical(ev.sel_tooSmallMS(:))) = {'tooSmall'};
if isfield(ev, 'sel_unclassified')
    labels(logical(ev.sel_unclassified(:))) = {'unclassified'};
end
end

function mask = get_event_mask(ev, field_name, ntrl)
if isfield(ev, field_name)
    mask = logical(ev.(field_name)(:));
else
    mask = false(ntrl, 1);
end
end

function m = safe_mean(x)
if isempty(x)
    m = NaN;
else
    m = mean(x, 'omitnan');
end
end

function r = safe_rate(num, den)
if den == 0
    r = NaN;
else
    r = num ./ den;
end
end

function T = build_condition_sensitivity(subj, cond_names, err_keep, rt_keep, n_keep, err_excl, rt_excl, n_excl)
subject = {};
condition = {};
n_current = [];
n_exclude_unusable = [];
n_removed_unusable_validRT = [];
error_current = [];
error_exclude_unusable = [];
delta_error_exclude_minus_current = [];
rt_current = [];
rt_exclude_unusable = [];
delta_RT_exclude_minus_current = [];

for is = 1:numel(subj)
    for ic = 1:numel(cond_names)
        subject{end+1,1} = subj{is}; %#ok<AGROW>
        condition{end+1,1} = cond_names{ic}; %#ok<AGROW>
        n_current(end+1,1) = n_keep(is,ic); %#ok<AGROW>
        n_exclude_unusable(end+1,1) = n_excl(is,ic); %#ok<AGROW>
        n_removed_unusable_validRT(end+1,1) = n_keep(is,ic) - n_excl(is,ic); %#ok<AGROW>
        error_current(end+1,1) = err_keep(is,ic); %#ok<AGROW>
        error_exclude_unusable(end+1,1) = err_excl(is,ic); %#ok<AGROW>
        delta_error_exclude_minus_current(end+1,1) = err_excl(is,ic) - err_keep(is,ic); %#ok<AGROW>
        rt_current(end+1,1) = rt_keep(is,ic); %#ok<AGROW>
        rt_exclude_unusable(end+1,1) = rt_excl(is,ic); %#ok<AGROW>
        delta_RT_exclude_minus_current(end+1,1) = rt_excl(is,ic) - rt_keep(is,ic); %#ok<AGROW>
    end
end

T = table(subject, condition, n_current, n_exclude_unusable, ...
    n_removed_unusable_validRT, error_current, error_exclude_unusable, ...
    delta_error_exclude_minus_current, rt_current, rt_exclude_unusable, ...
    delta_RT_exclude_minus_current);
end

function [G, C] = build_group_sensitivity(cond_names, err_keep, rt_keep, n_keep, err_excl, rt_excl, n_excl)
condition = cond_names(:);
mean_error_current = mean(err_keep, 1, 'omitnan')';
mean_error_exclude_unusable = mean(err_excl, 1, 'omitnan')';
delta_error_exclude_minus_current = mean_error_exclude_unusable - mean_error_current;
mean_RT_current = mean(rt_keep, 1, 'omitnan')';
mean_RT_exclude_unusable = mean(rt_excl, 1, 'omitnan')';
delta_RT_exclude_minus_current = mean_RT_exclude_unusable - mean_RT_current;
mean_n_current = mean(n_keep, 1, 'omitnan')';
mean_n_exclude_unusable = mean(n_excl, 1, 'omitnan')';
mean_n_removed_unusable_validRT = mean(n_keep - n_excl, 1, 'omitnan')';

G = table(condition, mean_n_current, mean_n_exclude_unusable, ...
    mean_n_removed_unusable_validRT, mean_error_current, ...
    mean_error_exclude_unusable, delta_error_exclude_minus_current, ...
    mean_RT_current, mean_RT_exclude_unusable, delta_RT_exclude_minus_current);

measure = {};
policy = {};
contrast = {};
mean_diff = [];
sd_diff = [];
se_diff = [];
t_value = [];
p_raw = [];
p_bonf3 = [];
n = [];
pairs = [1 2; 1 3; 2 3];
pair_names = {'toward-no','toward-away','no-away'};

for im = 1:2
    if im == 1
        M_keep = err_keep;
        M_excl = err_excl;
        measure_name = 'error';
    else
        M_keep = rt_keep;
        M_excl = rt_excl;
        measure_name = 'RT';
    end
    for ipol = 1:2
        if ipol == 1
            M = M_keep;
            policy_name = 'current_keep_unusable';
        else
            M = M_excl;
            policy_name = 'exclude_unusable';
        end
        for ip = 1:size(pairs,1)
            a = M(:, pairs(ip,1));
            b = M(:, pairs(ip,2));
            st = paired_stats(a, b);
            measure{end+1,1} = measure_name; %#ok<AGROW>
            policy{end+1,1} = policy_name; %#ok<AGROW>
            contrast{end+1,1} = pair_names{ip}; %#ok<AGROW>
            mean_diff(end+1,1) = st.mean_diff; %#ok<AGROW>
            sd_diff(end+1,1) = st.sd_diff; %#ok<AGROW>
            se_diff(end+1,1) = st.se_diff; %#ok<AGROW>
            t_value(end+1,1) = st.t_value; %#ok<AGROW>
            p_raw(end+1,1) = st.p_raw; %#ok<AGROW>
            p_bonf3(end+1,1) = min(st.p_raw * 3, 1); %#ok<AGROW>
            n(end+1,1) = st.n; %#ok<AGROW>
        end
    end
end

C = table(measure, policy, contrast, mean_diff, sd_diff, se_diff, ...
    t_value, p_raw, p_bonf3, n);
end

function S = paired_stats(a, b)
valid = ~isnan(a) & ~isnan(b);
d = a(valid) - b(valid);
S.n = numel(d);
S.mean_diff = safe_mean(d);
S.sd_diff = std(d, 'omitnan');
S.se_diff = S.sd_diff ./ sqrt(max(S.n, 1));
if S.n > 1 && S.sd_diff > 0
    [~, p, ~, st] = ttest(a(valid), b(valid));
    S.t_value = st.tstat;
    S.p_raw = p;
else
    S.t_value = NaN;
    S.p_raw = NaN;
end
end

function T = build_global_class_counts(trial_flags, class_names)
class_name = class_names(:);
n_trials = nan(numel(class_names), 1);
n_unusable = nan(numel(class_names), 1);
unusable_rate = nan(numel(class_names), 1);
n_valid_RT = nan(numel(class_names), 1);
mean_error_validRT = nan(numel(class_names), 1);
mean_RT_validRT = nan(numel(class_names), 1);

for ic = 1:numel(class_names)
    m = strcmp(trial_flags.class_name, class_names{ic});
    mv = m & trial_flags.valid_RT;
    n_trials(ic) = sum(m);
    n_unusable(ic) = sum(m & trial_flags.sel_unusable);
    unusable_rate(ic) = safe_rate(n_unusable(ic), n_trials(ic));
    n_valid_RT(ic) = sum(mv);
    mean_error_validRT(ic) = safe_mean(trial_flags.error(mv));
    mean_RT_validRT(ic) = safe_mean(trial_flags.RT(mv));
end
T = table(class_name, n_trials, n_unusable, unusable_rate, ...
    n_valid_RT, mean_error_validRT, mean_RT_validRT);
end

function T = build_global_session_counts(trial_flags)
session = [1; 2];
n_trials = nan(2,1);
n_unusable = nan(2,1);
unusable_rate = nan(2,1);
n_valid_RT = nan(2,1);
for i = 1:2
    m = trial_flags.session == session(i);
    n_trials(i) = sum(m);
    n_unusable(i) = sum(m & trial_flags.sel_unusable);
    unusable_rate(i) = safe_rate(n_unusable(i), n_trials(i));
    n_valid_RT(i) = sum(m & trial_flags.valid_RT);
end
T = table(session, n_trials, n_unusable, unusable_rate, n_valid_RT);
end
