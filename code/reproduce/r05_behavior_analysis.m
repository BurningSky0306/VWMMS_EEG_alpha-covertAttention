function r05_behavior_analysis()
% R05_BEHAVIOR_ANALYSIS
% Reproduce Fig 2 from local raw logs and current trial classes.
%
% This script deliberately keeps the local analysis primary. The optional
% Source Data comparison is diagnostic only: it checks whether the local
% trial-level pipeline reproduces the published Fig 2 summary values.

cfg = r00_setup();
subj = cfg.subj; nS = numel(subj);
condNames = {'toward','no','away'};

err = nan(nS,3); rt = nan(nS,3);
err_norm = nan(nS,3); rt_norm = nan(nS,3);
n_trials = nan(nS,3);
qc_counts = init_qc_counts(nS);

for is = 1:nS
    bef = fullfile(cfg.out_beh,   [subj{is} '.mat']);
    evf = fullfile(cfg.out_event, [subj{is} '.mat']);
    if ~exist(bef,'file') || ~exist(evf,'file')
        warning('Missing inputs for %s', subj{is});
        continue;
    end

    B = load(bef); behavior = B.behavior;
    E = load(evf); ev = E.event;

    sel_to = ev.sel_toward & behavior.valid_RT;
    sel_no = ev.sel_noMS    & behavior.valid_RT;
    sel_aw = ev.sel_away    & behavior.valid_RT;
    sels = {sel_to, sel_no, sel_aw};

    for k = 1:3
        err(is,k) = mean(behavior.error(sels{k}), 'omitnan');
        rt(is,k)  = mean(behavior.RT(sels{k}),    'omitnan');
        n_trials(is,k) = sum(sels{k});
    end

    mu_e = mean(err(is,:), 'omitnan');
    err_norm(is,:) = (err(is,:) - mu_e) ./ mu_e * 100;
    mu_r = mean(rt(is,:), 'omitnan');
    rt_norm(is,:) = (rt(is,:) - mu_r) ./ mu_r * 100;

    qc_counts.subject{is} = subj{is};
    qc_counts.total(is) = height(behavior);
    qc_counts.validRT(is) = sum(behavior.valid_RT);
    if isfield(ev, 'sel_main')
        qc_counts.main(is) = sum(ev.sel_main);
    else
        qc_counts.main(is) = NaN;
    end
    if isfield(ev, 'sel_unusable')
        qc_counts.unusable(is) = sum(ev.sel_unusable);
    else
        qc_counts.unusable(is) = NaN;
    end
    qc_counts.tooSmall(is) = sum(ev.sel_tooSmallMS);
    qc_counts.unclassified(is) = get_event_count(ev, 'sel_unclassified');

    fprintf(['%s | n(T/N/A)=%d/%d/%d | err T=%.2f N=%.2f A=%.2f | ' ...
             'RT T=%.1f N=%.1f A=%.1f\n'], ...
            subj{is}, n_trials(is,1), n_trials(is,2), n_trials(is,3), ...
            err(is,1), err(is,2), err(is,3), rt(is,1), rt(is,2), rt(is,3));
end

stats = struct();
stats.err = run_one_way_rmANOVA(err, condNames, 'Error (deg)');
stats.rt  = run_one_way_rmANOVA(rt,  condNames, 'RT (ms)');
stats.err.contrasts = contrast_summary(err, condNames);
stats.rt.contrasts  = contrast_summary(rt,  condNames);

fprintf('\n>>> Trial counts retained after RT trim (mean +/- SD):\n');
fprintf('  toward: %.1f +/- %.1f | no: %.1f +/- %.1f | away: %.1f +/- %.1f\n', ...
    mean(n_trials(:,1),'omitnan'), std(n_trials(:,1),'omitnan'), ...
    mean(n_trials(:,2),'omitnan'), std(n_trials(:,2),'omitnan'), ...
    mean(n_trials(:,3),'omitnan'), std(n_trials(:,3),'omitnan'));
print_contrasts(stats.err.contrasts, 'Error paired differences');
print_contrasts(stats.rt.contrasts,  'RT paired differences');

source_diag = compare_fig2_source_data(err, rt, cfg);

save(fullfile(cfg.out_results,'GA_behavior_stats.mat'), ...
     'err','rt','err_norm','rt_norm','n_trials','qc_counts','stats','source_diag','subj');

plot_fig2(err, rt, err_norm, rt_norm, stats, cfg);

fprintf('[r05] Done. Behavior analysis.\n');
end


function qc = init_qc_counts(nS)
qc = struct();
qc.subject = cell(nS,1);
qc.total = nan(nS,1);
qc.validRT = nan(nS,1);
qc.main = nan(nS,1);
qc.unusable = nan(nS,1);
qc.tooSmall = nan(nS,1);
qc.unclassified = nan(nS,1);
end


function n = get_event_count(ev, fieldname)
if isfield(ev, fieldname)
    n = sum(ev.(fieldname));
else
    n = NaN;
end
end


function S = run_one_way_rmANOVA(M, condNames, dvName)
nS = size(M,1);
valid_rows = all(~isnan(M), 2);
nValid = sum(valid_rows);
S = struct();
S.M = M;
S.condNames = {condNames};
S.dvName = dvName;
S.n = nValid;
S.mean = mean(M,1,'omitnan');
S.sem = std(M,0,1,'omitnan') ./ sqrt(sum(~isnan(M),1));

if nValid < 3
    warning('N=%d too small for RM-ANOVA on %s -- descriptive only.', nValid, dvName);
    S.F = NaN; S.p = NaN; S.partialEta2 = NaN; S.posthoc = struct();
    return;
end

M_valid = M(valid_rows,:);
T = array2table(M_valid, 'VariableNames', condNames);
within = table((1:numel(condNames))', 'VariableNames', {'cond'});
within.cond = categorical(within.cond);
rm = fitrm(T, sprintf('%s-%s ~ 1', condNames{1}, condNames{end}), 'WithinDesign', within);
ranovatbl = ranova(rm);

S.F = ranovatbl.F(1);
S.p = ranovatbl.pValue(1);
ss_effect = ranovatbl.SumSq(1);
ss_error  = ranovatbl.SumSq(2);
S.partialEta2 = ss_effect / (ss_effect + ss_error);

fprintf('\n>>> RM-ANOVA on %s: F(%d,%d)=%.2f, p=%.3f, partial eta^2=%.3f\n', ...
    dvName, ranovatbl.DF(1), ranovatbl.DF(2), S.F, S.p, S.partialEta2);

pairs = nchoosek(1:size(M,2), 2);
nP = size(pairs,1);
ph = struct('pair',{},'t',{},'p_raw',{},'p_bonf',{},'cohen_d',{}, ...
            'mean_diff',{},'sd_diff',{},'se_diff',{},'n',{});
for ip = 1:nP
    a = M(:,pairs(ip,1)); b = M(:,pairs(ip,2));
    valid = ~isnan(a) & ~isnan(b);
    diffVals = a(valid) - b(valid);
    [~,p,~,st] = ttest(a(valid), b(valid));
    d = mean(diffVals) / std(diffVals);
    ph(ip).pair = condNames(pairs(ip,:));
    ph(ip).t = st.tstat;
    ph(ip).p_raw = p;
    ph(ip).p_bonf = min(p*nP, 1);
    ph(ip).cohen_d = d;
    ph(ip).mean_diff = mean(diffVals);
    ph(ip).sd_diff = std(diffVals);
    ph(ip).se_diff = std(diffVals) / sqrt(numel(diffVals));
    ph(ip).n = numel(diffVals);
    fprintf(['  %s vs %s: t(%d)=%.2f, p_raw=%.3f, p_Bonf=%.3f, d=%.3f, ' ...
             'diff=%.3f +/- %.3f(SE)\n'], ...
        condNames{pairs(ip,1)}, condNames{pairs(ip,2)}, st.df, st.tstat, ...
        p, ph(ip).p_bonf, d, ph(ip).mean_diff, ph(ip).se_diff);
end
S.posthoc = ph;
end


function C = contrast_summary(M, condNames)
pairs = nchoosek(1:size(M,2), 2);
C = struct('pair',{},'mean_diff',{},'sd_diff',{},'se_diff',{},'n',{});
for ip = 1:size(pairs,1)
    a = M(:,pairs(ip,1)); b = M(:,pairs(ip,2));
    valid = ~isnan(a) & ~isnan(b);
    diffVals = a(valid) - b(valid);
    C(ip).pair = condNames(pairs(ip,:));
    C(ip).mean_diff = mean(diffVals);
    C(ip).sd_diff = std(diffVals);
    C(ip).se_diff = std(diffVals) / sqrt(numel(diffVals));
    C(ip).n = numel(diffVals);
end
end


function print_contrasts(C, label)
fprintf('\n>>> %s:\n', label);
for i = 1:numel(C)
    fprintf('  %s - %s: mean=%.3f, SD=%.3f, SE=%.3f, n=%d\n', ...
        C(i).pair{1}, C(i).pair{2}, C(i).mean_diff, C(i).sd_diff, C(i).se_diff, C(i).n);
end
end


function source_diag = compare_fig2_source_data(err, rt, cfg)
source_diag = struct('available', false, 'note', '');
url = ['https://static-content.springer.com/esm/art%3A10.1038%2F' ...
       's41467-022-31217-3/MediaObjects/41467_2022_31217_MOESM4_ESM.xlsx'];
cache_file = fullfile(tempdir, 'paper_fig2_source_data.xlsx');

try
    if ~exist(cache_file, 'file')
        fprintf('\nDownloading paper Fig 2 Source Data for diagnostic comparison...\n');
        websave(cache_file, url);
    end
    C = readcell(cache_file, 'Sheet', 'figure2');
    [paper_err, paper_rt] = extract_fig2_source_cells(C);

    source_diag.available = true;
    source_diag.url = url;
    source_diag.cache_file = cache_file;
    source_diag.paper_err = paper_err;
    source_diag.paper_rt = paper_rt;
    source_diag.local_err = err;
    source_diag.local_rt = rt;
    source_diag.mean_abs_diff_err = mean(abs(err - paper_err), 1, 'omitnan');
    source_diag.mean_abs_diff_rt  = mean(abs(rt  - paper_rt),  1, 'omitnan');
    source_diag.paper_err_contrasts = contrast_summary(paper_err, {'toward','no','away'});
    source_diag.paper_rt_contrasts  = contrast_summary(paper_rt,  {'toward','no','away'});

    fprintf('\n>>> Fig 2 Source Data diagnostic (same-row comparison, not used for local stats):\n');
    fprintf('  Paper means error: %.2f / %.2f / %.2f deg\n', mean(paper_err,1,'omitnan'));
    fprintf('  Local means error: %.2f / %.2f / %.2f deg\n', mean(err,1,'omitnan'));
    fprintf('  Mean abs diff error: %.3f / %.3f / %.3f deg\n', source_diag.mean_abs_diff_err);
    fprintf('  Paper means RT: %.1f / %.1f / %.1f ms\n', mean(paper_rt,1,'omitnan'));
    fprintf('  Local means RT: %.1f / %.1f / %.1f ms\n', mean(rt,1,'omitnan'));
    fprintf('  Mean abs diff RT: %.2f / %.2f / %.2f ms\n', source_diag.mean_abs_diff_rt);
    print_contrasts(source_diag.paper_err_contrasts, 'Paper Source Data error paired differences');
    print_contrasts(source_diag.paper_rt_contrasts,  'Paper Source Data RT paired differences');
catch ME
    source_diag.available = false;
    source_diag.note = ME.message;
    warning('Could not load paper Fig 2 Source Data: %s', ME.message);
end
end


function [paper_err, paper_rt] = extract_fig2_source_cells(C)
% readcell returns the used range, so absolute Excel row/column references are
% brittle. Locate the first raw-data header by content instead.
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
    if ~isempty(header_row), break; end
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
rt_cols  = toward_cols(2):(toward_cols(2)+2);
data_rows = (header_row+1):(header_row+23);
paper_err = cellblock_to_double(C(data_rows, err_cols));
paper_rt  = cellblock_to_double(C(data_rows, rt_cols));

% Basic sanity check: the first column after subjectID should contain numeric
% subject ids 1..23 in the same data rows.
subject_ids = cellblock_to_double(C(data_rows, header_col));
if numel(subject_ids) ~= 23 || any(isnan(subject_ids))
    warning('Source Data subject IDs could not be fully verified.');
end
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


function plot_fig2(err, rt, err_norm, rt_norm, stats, cfg)
fig = figure('position',[80 80 900 700], 'Color','w');
condNames = {'Toward','No','Away'};
condColor = [0.3 0.7 0.3; 0.5 0.5 0.5; 0.7 0.4 0.7];

for ip = 1:2
    if ip==1
        M = err; ttl = 'Error (deg)'; ylab='Error (deg)'; st = stats.err;
    else
        M = rt; ttl = 'RT (ms)'; ylab='RT (ms)'; st = stats.rt;
    end
    subplot(2,2,ip); hold on
    plot(1:3, M', '-', 'Color',[.7 .7 .7]);
    bar(1:3, mean(M,1,'omitnan'), 'FaceColor','flat','CData',condColor, 'FaceAlpha',0.6);
    errorbar(1:3, mean(M,1,'omitnan'), std(M,0,1,'omitnan')./sqrt(sum(~isnan(M),1)), ...
             'k.', 'LineWidth',1.5);
    set(gca,'XTick',1:3,'XTickLabel',condNames); ylabel(ylab); title(ttl)
    if isfield(st,'F') && ~isnan(st.F)
        text(0.05,0.95,sprintf('F=%.2f, p=%.3f', st.F, st.p), ...
             'Units','normalized','FontSize',9,'VerticalAlignment','top');
    end
end

for ip = 1:2
    if ip==1
        M = err_norm; ylab='Normalized error (delta %)';
    else
        M = rt_norm; ylab='Normalized RT (delta %)';
    end
    subplot(2,2,ip+2); hold on
    rng(1);
    for k=1:3
        scatter(repmat(k,size(M,1),1)+0.1*(rand(size(M,1),1)-.5), M(:,k), ...
                40, condColor(k,:), 'filled', 'MarkerFaceAlpha',0.6);
    end
    plot(1:3, mean(M,1,'omitnan'), 'k_', 'MarkerSize',25, 'LineWidth',2)
    set(gca,'XTick',1:3,'XTickLabel',condNames); ylabel(ylab)
    yline(0, '--', 'Color',[.5 .5 .5]);
end

sgtitle(sprintf('Fig 2 | Behavior x microsaccade class (N=%d)', size(err,1)))
saveas(fig, fullfile(cfg.out_figures,'fig2_behavior.png'));
fprintf('  Fig 2 saved.\n');
end
