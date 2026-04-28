function r05_behavior_analysis()
% R05_BEHAVIOR_ANALYSIS
% 复现论文 Fig 2：reproduction error 与 RT × {toward/no/away}
% 含描述统计 + One-way Repeated-Measures ANOVA + Bonferroni 事后 t + Cohen's d
%
% 论文统计原话：
%   "performing a one-way repeated-measures ANOVA (across the conditions
%    toward, no, and away) complemented with Bonferroni-corrected post hoc
%    t-tests. Cohen's d was used as a measure of effect size."
%
% 注：ANOVA 需要 N≥3 被试。N=2 时仅出描述统计，跳过推断。

cfg = r00_setup();
subj = cfg.subj; nS = numel(subj);

% [N x 3] 矩阵：列依次 toward / no / away
err = nan(nS,3); rt  = nan(nS,3);
err_norm = nan(nS,3); rt_norm = nan(nS,3);

for is = 1:nS
    bef = fullfile(cfg.out_beh,   [subj{is} '.mat']);
    evf = fullfile(cfg.out_event, [subj{is} '.mat']);
    if ~exist(bef,'file') || ~exist(evf,'file')
        warning('Missing inputs for %s', subj{is}); continue;
    end
    B = load(bef); behavior = B.behavior;
    E = load(evf); ev = E.event;

    sel_to  = ev.sel_toward & behavior.valid_RT;
    sel_no  = ev.sel_noMS    & behavior.valid_RT;
    sel_aw  = ev.sel_away    & behavior.valid_RT;

    err(is,1) = mean(behavior.error(sel_to),'omitnan');
    err(is,2) = mean(behavior.error(sel_no),'omitnan');
    err(is,3) = mean(behavior.error(sel_aw),'omitnan');

    rt(is,1) = mean(behavior.RT(sel_to),'omitnan');
    rt(is,2) = mean(behavior.RT(sel_no),'omitnan');
    rt(is,3) = mean(behavior.RT(sel_aw),'omitnan');

    % 归一化（论文下半图）：(val - mean_subj) / mean_subj × 100
    mu_e = mean(err(is,:),'omitnan');
    err_norm(is,:) = (err(is,:) - mu_e) ./ mu_e * 100;
    mu_r = mean(rt(is,:),'omitnan');
    rt_norm(is,:)  = (rt(is,:)  - mu_r) ./ mu_r * 100;

    fprintf('%s | err: T=%.2f° N=%.2f° A=%.2f°  | RT: T=%dms N=%dms A=%dms\n', ...
            subj{is}, err(is,1),err(is,2),err(is,3), ...
            round(rt(is,1)),round(rt(is,2)),round(rt(is,3)));
end

% ===== 描述统计 + 推断 =====
stats = struct();
stats.err = run_one_way_rmANOVA(err, {'toward','no','away'}, 'Error (deg)');
stats.rt  = run_one_way_rmANOVA(rt,  {'toward','no','away'}, 'RT (ms)');

save(fullfile(cfg.out_results,'GA_behavior_stats.mat'), ...
     'err','rt','err_norm','rt_norm','stats','subj');

% ===== 绘 Fig 2 =====
plot_fig2(err, rt, err_norm, rt_norm, stats, cfg);

fprintf('[r05] Done. Behavior analysis.\n');
end


% ============================================================
function S = run_one_way_rmANOVA(M, condNames, dvName)
% M: [N x K] subjects × conditions
% 返回 struct 含 means, sems, F, p, partialEta2, post-hoc t/p/d 矩阵
nS = size(M,1);
S = struct(); S.M = M; S.condNames = {condNames}; S.dvName = dvName;
S.mean = mean(M,1,'omitnan'); S.sem  = std(M,0,1,'omitnan')./sqrt(nS);

if nS < 3
    warning('N=%d too small for RM-ANOVA — descriptive only.', nS);
    S.F=NaN; S.p=NaN; S.partialEta2=NaN; S.posthoc=struct();
    fprintf('  [%s] descriptive: %s = %s\n', dvName, ...
            strjoin(condNames,'/'), num2str(S.mean,3));
    return;
end

% --- RM-ANOVA via fitrm + ranova (需要 Statistics & ML Toolbox) ---
T = array2table(M, 'VariableNames', condNames);
within = table((1:numel(condNames))', 'VariableNames', {'cond'});
within.cond = categorical(within.cond);
rm = fitrm(T, sprintf('%s-%s ~ 1', condNames{1}, condNames{end}), 'WithinDesign', within);
ranovatbl = ranova(rm);

S.F = ranovatbl.F(1);
S.p = ranovatbl.pValue(1);
ss_effect = ranovatbl.SumSq(1);
ss_error  = ranovatbl.SumSq(2);
S.partialEta2 = ss_effect / (ss_effect + ss_error);

fprintf('\n>>> RM-ANOVA on %s: F(%d,%d)=%.2f, p=%.3f, partial η²=%.3f\n', ...
    dvName, ranovatbl.DF(1), ranovatbl.DF(2), S.F, S.p, S.partialEta2);

% --- Bonferroni-corrected pairwise paired t-tests ---
pairs = nchoosek(1:size(M,2), 2);
nP = size(pairs,1);
ph = struct('pair',{},'t',{},'p_raw',{},'p_bonf',{},'cohen_d',{});
for ip = 1:nP
    a = M(:,pairs(ip,1)); b = M(:,pairs(ip,2));
    valid = ~isnan(a) & ~isnan(b);
    [~,p,~,st] = ttest(a(valid), b(valid));
    d = mean(a(valid)-b(valid)) / std(a(valid)-b(valid));   % Cohen's d (paired)
    ph(ip).pair    = condNames(pairs(ip,:));
    ph(ip).t       = st.tstat;
    ph(ip).p_raw   = p;
    ph(ip).p_bonf  = min(p*nP, 1);
    ph(ip).cohen_d = d;
    fprintf('  %s vs %s: t(%d)=%.2f, p_raw=%.3f, p_Bonf=%.3f, d=%.3f\n', ...
        condNames{pairs(ip,1)}, condNames{pairs(ip,2)}, st.df, st.tstat, p, ph(ip).p_bonf, d);
end
S.posthoc = ph;
end


% ============================================================
function plot_fig2(err, rt, err_norm, rt_norm, stats, cfg)
fig = figure('position',[80 80 900 700], 'Color','w');
condNames = {'Toward','No','Away'};
condColor = [0.3 0.7 0.3; 0.5 0.5 0.5; 0.7 0.4 0.7];

% --- Top row: raw means ± SEM with subject lines ---
for ip = 1:2
    if ip==1, M = err; ttl = 'Error (deg)'; ylab='Error (°)';
    else,     M = rt;  ttl = 'RT (ms)';     ylab='RT (ms)'; end
    subplot(2,2,ip); hold on
    plot(1:3, M', '-', 'Color',[.7 .7 .7]);
    bar(1:3, mean(M,1,'omitnan'), 'FaceColor','flat','CData',condColor, 'FaceAlpha',0.6);
    errorbar(1:3, mean(M,1,'omitnan'), std(M,0,1,'omitnan')./sqrt(size(M,1)), ...
             'k.', 'LineWidth',1.5);
    set(gca,'XTick',1:3,'XTickLabel',condNames); ylabel(ylab); title(ttl)
    if ~isnan(stats.err.F) && ip==1
        text(0.05,0.95,sprintf('F=%.2f, p=%.3f', stats.err.F, stats.err.p), ...
             'Units','normalized','FontSize',9,'VerticalAlignment','top');
    elseif ~isnan(stats.rt.F) && ip==2
        text(0.05,0.95,sprintf('F=%.2f, p=%.3f', stats.rt.F, stats.rt.p), ...
             'Units','normalized','FontSize',9,'VerticalAlignment','top');
    end
end

% --- Bottom row: normalized (Δ%) with subject dots ---
for ip = 1:2
    if ip==1, M = err_norm; ylab='Normalized error (Δ%)';
    else,     M = rt_norm;  ylab='Normalized RT (Δ%)'; end
    subplot(2,2,ip+2); hold on
    for k=1:3
        scatter(repmat(k,size(M,1),1)+0.1*(rand(size(M,1),1)-.5), M(:,k), ...
                40, condColor(k,:), 'filled', 'MarkerFaceAlpha',0.6);
    end
    plot(1:3, mean(M,1,'omitnan'), 'k_', 'MarkerSize',25, 'LineWidth',2)
    set(gca,'XTick',1:3,'XTickLabel',condNames); ylabel(ylab)
    yline(0, '--', 'Color',[.5 .5 .5]);
end

sgtitle(sprintf('Fig 2 | Behavior × microsaccade class (N=%d)', size(err,1)))
saveas(fig, fullfile(cfg.out_figures,'fig2_behavior.png'));
fprintf('  Fig 2 saved.\n');
end
