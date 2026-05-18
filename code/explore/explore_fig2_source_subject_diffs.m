function source_diag = explore_fig2_source_subject_diffs(cfg, out_dir, nan_diag)
% EXPLORE_FIG2_SOURCE_SUBJECT_DIFFS
% Read-only subject/condition comparison against the paper Fig. 2 Source Data.
% Writes only under results/exploration.

if nargin < 1 || isempty(cfg)
    cfg = r00_setup();
end
if nargin < 2 || isempty(out_dir)
    out_dir = fullfile(cfg.out_results, 'exploration');
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
if nargin < 3 || isempty(nan_diag)
    diag_file = fullfile(out_dir, 'nan_unusable_distribution.mat');
    if exist(diag_file, 'file')
        tmp = load(diag_file);
        nan_diag = tmp.nan_diag;
    else
        nan_diag = [];
    end
end

ga_file = fullfile(cfg.out_results, 'GA_behavior_stats.mat');
require_file(ga_file);
G = load(ga_file);
assert(isfield(G, 'err') && isfield(G, 'rt') && isfield(G, 'n_trials'), ...
    'GA_behavior_stats.mat is missing expected err/rt/n_trials fields.');

[paper_err, paper_rt, paper_subject_id, source_meta] = load_fig2_source_data();
assert(size(paper_err,1) == numel(cfg.subj), 'Source Data row count is not 23.');
assert(size(paper_rt,1) == numel(cfg.subj), 'Source Data row count is not 23.');

cond_names = {'toward','no','away'};
cond_fields = {'sel_toward','sel_noMS','sel_away'};
nS = numel(cfg.subj);
n_cond = numel(cond_names);

subject = {};
paper_subject = [];
condition = {};
local_error = [];
paper_error = [];
diff_error_local_minus_paper = [];
abs_diff_error = [];
local_RT = [];
paper_RT = [];
diff_RT_local_minus_paper = [];
abs_diff_RT = [];
local_n_valid = [];
local_n_total_class = [];
local_n_unusable_class = [];
local_n_trimmed_class = [];

for is = 1:nS
    subj = cfg.subj{is};
    E = load(fullfile(cfg.out_event, [subj '.mat']));
    B = load(fullfile(cfg.out_beh, [subj '.mat']));
    ev = E.event;
    behavior = B.behavior;
    valid_rt = logical(behavior.valid_RT(:));
    unusable = logical(ev.sel_unusable(:));

    for ic = 1:n_cond
        class_mask = logical(ev.(cond_fields{ic})(:));
        subject{end+1,1} = subj; %#ok<AGROW>
        paper_subject(end+1,1) = paper_subject_id(is); %#ok<AGROW>
        condition{end+1,1} = cond_names{ic}; %#ok<AGROW>
        local_error(end+1,1) = G.err(is,ic); %#ok<AGROW>
        paper_error(end+1,1) = paper_err(is,ic); %#ok<AGROW>
        diff_error_local_minus_paper(end+1,1) = G.err(is,ic) - paper_err(is,ic); %#ok<AGROW>
        abs_diff_error(end+1,1) = abs(G.err(is,ic) - paper_err(is,ic)); %#ok<AGROW>
        local_RT(end+1,1) = G.rt(is,ic); %#ok<AGROW>
        paper_RT(end+1,1) = paper_rt(is,ic); %#ok<AGROW>
        diff_RT_local_minus_paper(end+1,1) = G.rt(is,ic) - paper_rt(is,ic); %#ok<AGROW>
        abs_diff_RT(end+1,1) = abs(G.rt(is,ic) - paper_rt(is,ic)); %#ok<AGROW>
        local_n_valid(end+1,1) = G.n_trials(is,ic); %#ok<AGROW>
        local_n_total_class(end+1,1) = sum(class_mask); %#ok<AGROW>
        local_n_unusable_class(end+1,1) = sum(class_mask & unusable); %#ok<AGROW>
        local_n_trimmed_class(end+1,1) = sum(class_mask & ~valid_rt); %#ok<AGROW>
    end
end

diff_table = table(subject, paper_subject, condition, local_error, paper_error, ...
    diff_error_local_minus_paper, abs_diff_error, local_RT, paper_RT, ...
    diff_RT_local_minus_paper, abs_diff_RT, local_n_valid, local_n_total_class, ...
    local_n_unusable_class, local_n_trimmed_class);

top_error = sortrows(diff_table, 'abs_diff_error', 'descend');
top_rt = sortrows(diff_table, 'abs_diff_RT', 'descend');

selected_pairs = pick_top_pairs(top_error, top_rt, 8);
[trial_detail, pair_summary] = inspect_selected_pairs(cfg, selected_pairs, ...
    paper_err, paper_rt, G.err, G.rt);

source_diag = struct();
source_diag.source_meta = source_meta;
source_diag.paper_subject_id = paper_subject_id;
source_diag.paper_err = paper_err;
source_diag.paper_rt = paper_rt;
source_diag.local_err = G.err;
source_diag.local_rt = G.rt;
source_diag.diff_table = diff_table;
source_diag.top_error = top_error;
source_diag.top_rt = top_rt;
source_diag.selected_pairs = selected_pairs;
source_diag.trial_detail = trial_detail;
source_diag.pair_summary = pair_summary;
source_diag.mean_abs_diff_error = mean(abs(G.err - paper_err), 1, 'omitnan');
source_diag.mean_abs_diff_RT = mean(abs(G.rt - paper_rt), 1, 'omitnan');

if ~isempty(nan_diag)
    source_diag.nan_unusable_class_counts = nan_diag.global_class_counts;
    source_diag.nan_unusable_session_counts = nan_diag.global_session_counts;
end

source_diag.paths = struct();
source_diag.paths.mat = fullfile(out_dir, 'fig2_source_subject_diffs.mat');
source_diag.paths.diff_csv = fullfile(out_dir, 'fig2_source_subject_condition_diffs.csv');
source_diag.paths.top_error_csv = fullfile(out_dir, 'fig2_source_top_error_diffs.csv');
source_diag.paths.top_rt_csv = fullfile(out_dir, 'fig2_source_top_rt_diffs.csv');
source_diag.paths.trial_detail_csv = fullfile(out_dir, 'fig2_source_top_trial_detail.csv');
source_diag.paths.pair_summary_csv = fullfile(out_dir, 'fig2_source_top_pair_summary.csv');

save(source_diag.paths.mat, 'source_diag');
writetable(diff_table, source_diag.paths.diff_csv);
writetable(top_error, source_diag.paths.top_error_csv);
writetable(top_rt, source_diag.paths.top_rt_csv);
writetable(trial_detail, source_diag.paths.trial_detail_csv);
writetable(pair_summary, source_diag.paths.pair_summary_csv);

fprintf('[explore] Fig. 2 Source Data diagnostic saved under %s\n', out_dir);
end

function require_file(path_in)
if ~exist(path_in, 'file')
    error('Required file not found: %s', path_in);
end
end

function [paper_err, paper_rt, subject_ids, meta] = load_fig2_source_data()
url = ['https://static-content.springer.com/esm/art%3A10.1038%2F' ...
       's41467-022-31217-3/MediaObjects/41467_2022_31217_MOESM4_ESM.xlsx'];
cache_file = fullfile(tempdir, 'paper_fig2_source_data.xlsx');
if ~exist(cache_file, 'file')
    websave(cache_file, url);
end
C = readcell(cache_file, 'Sheet', 'figure2');
[paper_err, paper_rt, subject_ids, header_row, header_col, err_cols, rt_cols] = ...
    extract_fig2_source_cells(C);
meta = struct();
meta.url = url;
meta.cache_file = cache_file;
meta.sheet = 'figure2';
meta.header_row = header_row;
meta.subject_header_col = header_col;
meta.error_cols = err_cols;
meta.rt_cols = rt_cols;
meta.row_count = size(paper_err, 1);
meta.sanity_passed = size(paper_err,1) == 23 && size(paper_rt,1) == 23 && ...
    numel(subject_ids) == 23 && all(~isnan(subject_ids));
if ~meta.sanity_passed
    error('Fig. 2 Source Data sanity check failed.');
end
end

function [paper_err, paper_rt, subject_ids, header_row, header_col, err_cols, rt_cols] = extract_fig2_source_cells(C)
header_row = [];
header_col = [];
for r = 1:size(C,1)
    for c = 1:size(C,2)
        if is_text_equal(C{r,c}, 'subjectID')
            header_row = r;
            header_col = c;
            break;
        end
    end
    if ~isempty(header_row)
        break;
    end
end
if isempty(header_row)
    error('Could not locate subjectID header in Source Data workbook.');
end

header = C(header_row,:);
toward_cols = [];
for c = 1:numel(header)
    if is_text_equal(header{c}, 'toward')
        toward_cols(end+1) = c; %#ok<AGROW>
    end
end
if numel(toward_cols) < 2
    error('Could not locate raw error/RT toward columns in Source Data workbook.');
end

err_cols = toward_cols(1):(toward_cols(1)+2);
rt_cols = toward_cols(2):(toward_cols(2)+2);
data_rows = (header_row + 1):(header_row + 23);
paper_err = cellblock_to_double(C(data_rows, err_cols));
paper_rt = cellblock_to_double(C(data_rows, rt_cols));
subject_ids = cellblock_to_double(C(data_rows, header_col));
end

function tf = is_text_equal(x, target)
tf = false;
if ischar(x) || isstring(x)
    tf = strcmpi(strtrim(string(x)), target);
end
end

function M = cellblock_to_double(C)
M = nan(size(C));
for i = 1:numel(C)
    if isnumeric(C{i})
        M(i) = C{i};
    elseif ischar(C{i}) || isstring(C{i})
        M(i) = str2double(C{i});
    end
end
end

function selected_pairs = pick_top_pairs(top_error, top_rt, max_pairs)
subject = {};
condition = {};
source_rank = {};
seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');

for i = 1:min(height(top_error), max_pairs)
    key = [top_error.subject{i} '|' top_error.condition{i}];
    if ~isKey(seen, key)
        seen(key) = true;
        subject{end+1,1} = top_error.subject{i}; %#ok<AGROW>
        condition{end+1,1} = top_error.condition{i}; %#ok<AGROW>
        source_rank{end+1,1} = sprintf('error_rank_%d', i); %#ok<AGROW>
    end
end
for i = 1:min(height(top_rt), max_pairs)
    key = [top_rt.subject{i} '|' top_rt.condition{i}];
    if ~isKey(seen, key)
        seen(key) = true;
        subject{end+1,1} = top_rt.subject{i}; %#ok<AGROW>
        condition{end+1,1} = top_rt.condition{i}; %#ok<AGROW>
        source_rank{end+1,1} = sprintf('RT_rank_%d', i); %#ok<AGROW>
    end
end

selected_pairs = table(subject, condition, source_rank);
end

function [trial_detail, pair_summary] = inspect_selected_pairs(cfg, selected_pairs, paper_err, paper_rt, local_err, local_rt)
cond_names = {'toward','no','away'};
cond_fields = {'sel_toward','sel_noMS','sel_away'};

d_pair = {};
d_subject = {};
d_condition = {};
d_trial = [];
d_session = [];
d_cue = {};
d_class = {};
d_valid = [];
d_unusable = [];
d_too_small = [];
d_RT = [];
d_error = [];
d_first_raw_latency = [];
d_first_raw_size = [];
d_first_kept_latency = [];
d_first_kept_size = [];
d_n_raw_shift = [];
d_n_kept_shift = [];
d_n_small_shift = [];
d_small_before_kept = [];
d_close_time_boundary = [];
d_close_size_boundary = [];

s_subject = {};
s_condition = {};
s_source_rank = {};
s_local_error = [];
s_paper_error = [];
s_abs_diff_error = [];
s_local_RT = [];
s_paper_RT = [];
s_abs_diff_RT = [];
s_n_class = [];
s_n_valid = [];
s_n_valid_unusable = [];
s_n_unusable = [];
s_n_trimmed = [];
s_n_small_before_kept = [];
s_n_close_time_boundary = [];
s_n_close_size_boundary = [];
s_mean_error_current = [];
s_mean_error_exclude_unusable = [];
s_mean_RT_current = [];
s_mean_RT_exclude_unusable = [];

for ip = 1:height(selected_pairs)
    subj = selected_pairs.subject{ip};
    cond = selected_pairs.condition{ip};
    is = find(strcmp(cfg.subj, subj), 1);
    ic = find(strcmp(cond_names, cond), 1);
    if isempty(is) || isempty(ic)
        error('Unknown selected pair: %s %s', subj, cond);
    end

    E = load(fullfile(cfg.out_event, [subj '.mat']));
    B = load(fullfile(cfg.out_beh, [subj '.mat']));
    S = load(fullfile(cfg.out_shift, [subj '.mat']));
    ev = E.event;
    behavior = B.behavior;
    data_shift = S.data_shift;

    class_mask = logical(ev.(cond_fields{ic})(:));
    valid_rt = logical(behavior.valid_RT(:));
    unusable = logical(ev.sel_unusable(:));
    too_small = logical(ev.sel_tooSmallMS(:));
    ntrl = height(behavior);
    cue_labels = cue_side_labels(data_shift.trialinfo(:), cfg);
    class_labels = get_trial_class(ev, ntrl);

    [features, pair_counts] = shift_features(data_shift, cfg);
    row_mask = class_mask;
    rows = find(row_mask);
    pair_key = [subj '_' cond];

    for ii = 1:numel(rows)
        tr = rows(ii);
        d_pair{end+1,1} = pair_key; %#ok<AGROW>
        d_subject{end+1,1} = subj; %#ok<AGROW>
        d_condition{end+1,1} = cond; %#ok<AGROW>
        d_trial(end+1,1) = tr; %#ok<AGROW>
        d_session(end+1,1) = behavior.session(tr); %#ok<AGROW>
        d_cue{end+1,1} = cue_labels{tr}; %#ok<AGROW>
        d_class{end+1,1} = class_labels{tr}; %#ok<AGROW>
        d_valid(end+1,1) = valid_rt(tr); %#ok<AGROW>
        d_unusable(end+1,1) = unusable(tr); %#ok<AGROW>
        d_too_small(end+1,1) = too_small(tr); %#ok<AGROW>
        d_RT(end+1,1) = behavior.RT(tr); %#ok<AGROW>
        d_error(end+1,1) = behavior.error(tr); %#ok<AGROW>
        d_first_raw_latency(end+1,1) = features.first_raw_latency_s(tr); %#ok<AGROW>
        d_first_raw_size(end+1,1) = features.first_raw_size_pct(tr); %#ok<AGROW>
        d_first_kept_latency(end+1,1) = features.first_kept_latency_s(tr); %#ok<AGROW>
        d_first_kept_size(end+1,1) = features.first_kept_size_pct(tr); %#ok<AGROW>
        d_n_raw_shift(end+1,1) = features.n_raw_shift_200_600(tr); %#ok<AGROW>
        d_n_kept_shift(end+1,1) = features.n_kept_shift_200_600(tr); %#ok<AGROW>
        d_n_small_shift(end+1,1) = features.n_small_shift_200_600(tr); %#ok<AGROW>
        d_small_before_kept(end+1,1) = features.small_before_kept(tr); %#ok<AGROW>
        d_close_time_boundary(end+1,1) = features.close_time_boundary(tr); %#ok<AGROW>
        d_close_size_boundary(end+1,1) = features.close_size_boundary(tr); %#ok<AGROW>
    end

    current_mask = class_mask & valid_rt;
    exclude_unusable_mask = current_mask & ~unusable;
    s_subject{end+1,1} = subj; %#ok<AGROW>
    s_condition{end+1,1} = cond; %#ok<AGROW>
    s_source_rank{end+1,1} = selected_pairs.source_rank{ip}; %#ok<AGROW>
    s_local_error(end+1,1) = local_err(is,ic); %#ok<AGROW>
    s_paper_error(end+1,1) = paper_err(is,ic); %#ok<AGROW>
    s_abs_diff_error(end+1,1) = abs(local_err(is,ic) - paper_err(is,ic)); %#ok<AGROW>
    s_local_RT(end+1,1) = local_rt(is,ic); %#ok<AGROW>
    s_paper_RT(end+1,1) = paper_rt(is,ic); %#ok<AGROW>
    s_abs_diff_RT(end+1,1) = abs(local_rt(is,ic) - paper_rt(is,ic)); %#ok<AGROW>
    s_n_class(end+1,1) = sum(class_mask); %#ok<AGROW>
    s_n_valid(end+1,1) = sum(current_mask); %#ok<AGROW>
    s_n_valid_unusable(end+1,1) = sum(current_mask & unusable); %#ok<AGROW>
    s_n_unusable(end+1,1) = sum(class_mask & unusable); %#ok<AGROW>
    s_n_trimmed(end+1,1) = sum(class_mask & ~valid_rt); %#ok<AGROW>
    s_n_small_before_kept(end+1,1) = sum(class_mask & pair_counts.small_before_kept); %#ok<AGROW>
    s_n_close_time_boundary(end+1,1) = sum(class_mask & pair_counts.close_time_boundary); %#ok<AGROW>
    s_n_close_size_boundary(end+1,1) = sum(class_mask & pair_counts.close_size_boundary); %#ok<AGROW>
    s_mean_error_current(end+1,1) = safe_mean(behavior.error(current_mask)); %#ok<AGROW>
    s_mean_error_exclude_unusable(end+1,1) = safe_mean(behavior.error(exclude_unusable_mask)); %#ok<AGROW>
    s_mean_RT_current(end+1,1) = safe_mean(behavior.RT(current_mask)); %#ok<AGROW>
    s_mean_RT_exclude_unusable(end+1,1) = safe_mean(behavior.RT(exclude_unusable_mask)); %#ok<AGROW>
end

trial_detail = table(d_pair, d_subject, d_condition, d_trial, d_session, d_cue, ...
    d_class, d_valid, d_unusable, d_too_small, d_RT, d_error, ...
    d_first_raw_latency, d_first_raw_size, d_first_kept_latency, ...
    d_first_kept_size, d_n_raw_shift, d_n_kept_shift, d_n_small_shift, ...
    d_small_before_kept, d_close_time_boundary, d_close_size_boundary, ...
    'VariableNames', {'diagnostic_pair','subject','condition','trial_index', ...
    'session','cue_side','class_name','valid_RT','sel_unusable','sel_tooSmallMS', ...
    'RT','error','first_raw_latency_s','first_raw_size_pct', ...
    'first_kept_latency_s','first_kept_size_pct','n_raw_shift_200_600', ...
    'n_kept_shift_200_600','n_small_shift_200_600','small_before_kept', ...
    'close_time_boundary_10ms','close_size_boundary_0p9_1p1pct'});

pair_summary = table(s_subject, s_condition, s_source_rank, s_local_error, ...
    s_paper_error, s_abs_diff_error, s_local_RT, s_paper_RT, s_abs_diff_RT, ...
    s_n_class, s_n_valid, s_n_valid_unusable, s_n_unusable, s_n_trimmed, ...
    s_n_small_before_kept, s_n_close_time_boundary, s_n_close_size_boundary, ...
    s_mean_error_current, s_mean_error_exclude_unusable, s_mean_RT_current, ...
    s_mean_RT_exclude_unusable, ...
    'VariableNames', {'subject','condition','source_rank','local_error','paper_error', ...
    'abs_diff_error','local_RT','paper_RT','abs_diff_RT','n_class','n_valid_RT', ...
    'n_validRT_unusable','n_unusable','n_trimmed_RT','n_small_before_kept', ...
    'n_close_time_boundary_10ms','n_close_size_boundary_0p9_1p1pct', ...
    'mean_error_current','mean_error_exclude_unusable','mean_RT_current', ...
    'mean_RT_exclude_unusable'});
end

function [features, counts] = shift_features(data_shift, cfg)
sel_idx = dsearchn(data_shift.time(:), cfg.sort.t_window(:));
sel_idx = sel_idx(1):sel_idx(2);
time_win = data_shift.time(sel_idx);
shift_raw = data_shift.shift(:, sel_idx);
shift_kept = shift_raw;
shift_kept(abs(shift_kept) < cfg.sort.shift_min) = 0;

ntrl = size(shift_raw, 1);
first_raw_latency_s = nan(ntrl,1);
first_raw_size_pct = nan(ntrl,1);
first_kept_latency_s = nan(ntrl,1);
first_kept_size_pct = nan(ntrl,1);
n_raw_shift_200_600 = zeros(ntrl,1);
n_kept_shift_200_600 = zeros(ntrl,1);
n_small_shift_200_600 = zeros(ntrl,1);
small_before_kept = false(ntrl,1);
close_time_boundary = false(ntrl,1);
close_size_boundary = false(ntrl,1);

for tr = 1:ntrl
    raw_idx = find(shift_raw(tr,:) ~= 0 & ~isnan(shift_raw(tr,:)));
    kept_idx = find(shift_kept(tr,:) ~= 0 & ~isnan(shift_kept(tr,:)));
    small_idx = find(shift_raw(tr,:) ~= 0 & shift_kept(tr,:) == 0 & ~isnan(shift_raw(tr,:)));

    n_raw_shift_200_600(tr) = numel(raw_idx);
    n_kept_shift_200_600(tr) = numel(kept_idx);
    n_small_shift_200_600(tr) = numel(small_idx);

    if ~isempty(raw_idx)
        first_raw_latency_s(tr) = time_win(raw_idx(1));
        first_raw_size_pct(tr) = shift_raw(tr, raw_idx(1));
        close_time_boundary(tr) = min(abs(first_raw_latency_s(tr) - [0.2 0.6])) <= 0.010;
    end
    if ~isempty(kept_idx)
        first_kept_latency_s(tr) = time_win(kept_idx(1));
        first_kept_size_pct(tr) = shift_kept(tr, kept_idx(1));
        close_time_boundary(tr) = close_time_boundary(tr) || ...
            min(abs(first_kept_latency_s(tr) - [0.2 0.6])) <= 0.010;
    end
    if ~isempty(small_idx)
        if isempty(kept_idx)
            small_before_kept(tr) = true;
        else
            small_before_kept(tr) = small_idx(1) < kept_idx(1);
        end
    end

    boundary_sizes = abs(shift_raw(tr, raw_idx));
    close_size_boundary(tr) = any(boundary_sizes >= 0.9 & boundary_sizes <= 1.1);
end

features = table(first_raw_latency_s, first_raw_size_pct, first_kept_latency_s, ...
    first_kept_size_pct, n_raw_shift_200_600, n_kept_shift_200_600, ...
    n_small_shift_200_600, small_before_kept, close_time_boundary, close_size_boundary);
counts = struct();
counts.small_before_kept = small_before_kept;
counts.close_time_boundary = close_time_boundary;
counts.close_size_boundary = close_size_boundary;
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

function m = safe_mean(x)
if isempty(x)
    m = NaN;
else
    m = mean(x, 'omitnan');
end
end
