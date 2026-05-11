function r06_group_rate_clusterperm()
% R06_GROUP_RATE_CLUSTERPERM
% 复现论文 Fig 1b：跨被试的 toward / away gaze-shift rate 时间序列
% + cluster-based permutation test 标黑横线（toward vs away）
%
% 计算思路（与论文一致，避开按 size 分箱）：
%   每被试 → 二值化的 toward/away 眼跳事件矩阵 → 50 ms 移动平均 × 1000 → Hz
%   再跨被试求均 + 95% CI，统计用配对 cluster perm。

cfg = r00_setup();
slideWin_ms = 50;
xli = [-0.2 1];

GA_to = []; GA_aw = []; tvec = [];
for is = 1:numel(cfg.subj)
    sf = fullfile(cfg.out_shift, [cfg.subj{is} '.mat']);
    if ~exist(sf,'file'), continue; end
    S = load(sf); ds = S.data_shift;

    shift = ds.shift;
    trialinfo = ds.trialinfo;
    sel_left  = ismember(trialinfo, cfg.trig.cue_left);
    sel_right = ismember(trialinfo, cfg.trig.cue_right);

    shift_left  = shift < 0;        % 向左眼跳
    shift_right = shift > 0;        % 向右眼跳

    % toward = (left-cue 向左 + right-cue 向右) / 2  →  对称化
    toward_pertime = (mean(shift_left(sel_left,:),1) + ...
                      mean(shift_right(sel_right,:),1)) / 2;
    away_pertime   = (mean(shift_left(sel_right,:),1) + ...
                      mean(shift_right(sel_left,:),1)) / 2;

    GA_to(is,:) = smoothdata(toward_pertime,2,'movmean',slideWin_ms) * 1000;  % Hz
    GA_aw(is,:) = smoothdata(away_pertime,  2,'movmean',slideWin_ms) * 1000;
    tvec = ds.time;
end

% 时间窗截到 [-0.2, 1] 做统计与绘图
sel_t = tvec >= xli(1) & tvec <= xli(2);
GA_to_w = GA_to(:,sel_t); GA_aw_w = GA_aw(:,sel_t);
tvec_w  = tvec(sel_t);

% --- Cluster permutation ---
N = size(GA_to_w,1);
sig_time_mask = false(size(tvec_w));
if N < 3
    warning('N=%d → cluster permutation skipped (purely descriptive).', N);
    out = struct('clusters',[], 'sigMask',false(size(tvec_w)));
else
    if cfg.use_fieldtrip
        % FieldTrip: ft_timelockstatistics 配对 cluster permutation
        cfg.add_fieldtrip();

        data_toward = [];
        data_toward.label    = {'rate'};
        data_toward.time     = {tvec_w};
        data_toward.dimord   = 'rpt_time';
        data_toward.trial    = GA_to_w;

        data_away = [];
        data_away.label    = {'rate'};
        data_away.time     = {tvec_w};
        data_away.dimord   = 'rpt_time';
        data_away.trial    = GA_aw_w;

        stat_cfg = [];
        stat_cfg.method           = 'montecarlo';
        stat_cfg.statistic        = 'depsamplesT';
        stat_cfg.correctm         = 'cluster';
        stat_cfg.clusteralpha     = 0.05;
        stat_cfg.clusterstatistic = 'maxsum';
        stat_cfg.tail             = 0;
        stat_cfg.alpha            = 0.05;
        stat_cfg.numrandomization = 5000;
        stat_cfg.design = [1:N, 1:N; ones(1,N), 2*ones(1,N)];
        stat_cfg.ivar = 2;
        stat_cfg.uvar = 1;

        stat = ft_timelockstatistics(stat_cfg, data_toward, data_away);
        sig_time_mask = stat.mask(:)';

        nPos = numel(stat.posclusters);
        nSigPos = sum([stat.posclusters.p] < 0.05);
        fprintf('FieldTrip cluster perm: %d positive cluster(s) (of %d).\n', nSigPos, nPos);
        for ic = 1:nPos
            c = stat.posclusters(ic);
            if c.prob < 0.05
                fprintf('  Positive cluster %d: p=%.4f\n', ic, c.prob);
            end
        end
        nNeg = numel(stat.negclusters);
        nSigNeg = sum([stat.negclusters.p] < 0.05);
        fprintf('FieldTrip cluster perm: %d negative cluster(s) (of %d).\n', nSigNeg, nNeg);
        for ic = 1:nNeg
            c = stat.negclusters(ic);
            if c.prob < 0.05
                fprintf('  Negative cluster %d: p=%.4f\n', ic, c.prob);
            end
        end
        out = struct('stat', stat, 'sigMask', sig_time_mask);

    else
        out = helper_cluster_perm_1d(GA_to_w, GA_aw_w, 'nPerm',5000, 'alpha',0.05, 'tail',0);
        sig_time_mask = out.sigMask;
        nClust = sum([out.clusters.p] < 0.05);
        fprintf('Cluster perm: %d significant cluster(s) (of %d).\n', nClust, numel(out.clusters));
        for ic = 1:numel(out.clusters)
            c = out.clusters(ic);
            fprintf('  Cluster %d: t = %.3f ~ %.3f s, t-mass=%.1f, p=%.4f\n', ...
                ic, tvec_w(c.start), tvec_w(c.stop), c.mass, c.p);
        end
    end
end

% --- 绘图 (Fig 1b) ---
fig = figure('position',[100 100 700 350],'Color','w'); hold on
mTo = mean(GA_to_w,1,'omitnan'); seTo = std(GA_to_w,0,1,'omitnan')./sqrt(N) * 1.96;
mAw = mean(GA_aw_w,1,'omitnan'); seAw = std(GA_aw_w,0,1,'omitnan')./sqrt(N) * 1.96;
fill([tvec_w fliplr(tvec_w)],[mTo+seTo fliplr(mTo-seTo)],[0.3 0.7 0.3], ...
     'EdgeColor','none','FaceAlpha',0.25);
fill([tvec_w fliplr(tvec_w)],[mAw+seAw fliplr(mAw-seAw)],[0.7 0.4 0.7], ...
     'EdgeColor','none','FaceAlpha',0.25);
plot(tvec_w, mTo, 'Color',[0.3 0.7 0.3], 'LineWidth',2);
plot(tvec_w, mAw, 'Color',[0.7 0.4 0.7], 'LineWidth',2);
xline(0,'--k'); xlim(xli); xlabel('time after cue (s)'); ylabel('Rate (Hz)');
legend({'95% CI Toward','95% CI Away','Toward','Away'}, 'Location','best','box','off');

% Black horizontal line for significant cluster (paper Fig 1b)
yl = ylim; ybar = yl(1) + 0.03*diff(yl);
sm = sig_time_mask;
edges = diff([0 sm 0]);
ss = find(edges==1); ee = find(edges==-1)-1;
for k = 1:numel(ss)
    plot(tvec_w(ss(k):ee(k)), ybar*ones(1, ee(k)-ss(k)+1), 'k-', 'LineWidth',3);
end
title(sprintf('Fig 1b | gaze-shift rate (N=%d)', N));

saveas(fig, fullfile(cfg.out_figures,'fig1b_rate_timecourse.png'));
save(fullfile(cfg.out_results,'GA_rate_timecourse.mat'), ...
     'GA_to','GA_aw','tvec','out','cfg');
fprintf('[r06] Done. Fig 1b + cluster perm.\n');
end
