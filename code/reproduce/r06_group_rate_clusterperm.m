function r06_group_rate_clusterperm()
% R06_GROUP_RATE_CLUSTERPERM
% Reproduce Fig 1b gaze-shift rate time courses.
%
% One cluster permutation is run across cfg.stats.rate_wide_window, currently
% [-0.2 1.0] s. Significant clusters are marked with black horizontal bars
% and are not included in the legend.
%
% Both summaries use the same cleaned event matrix: shifts smaller than
% cfg.sort.shift_min are ignored, and the cfg.sort.exclude_unusable_from_main
% policy is applied consistently when event_TAN_mini1/sNN.mat is available.

cfg = r00_setup();
slideWin_ms = 50;
xli = cfg.stats.rate_wide_window;

GA_to = [];
GA_aw = [];
tvec = [];
subject_used = {};

for is = 1:numel(cfg.subj)
    subj = cfg.subj{is};
    sf = fullfile(cfg.out_shift, [subj '.mat']);
    if ~exist(sf,'file')
        warning('Missing %s -- skip', sf);
        continue;
    end
    S = load(sf); ds = S.data_shift;

    shift = ds.shift;
    shift(abs(shift) < cfg.sort.shift_min) = 0;
    trialinfo = ds.trialinfo;
    sel_trials = true(size(trialinfo));

    evf = fullfile(cfg.out_event, [subj '.mat']);
    if exist(evf, 'file')
        E = load(evf); ev = E.event;
        if isfield(ev, 'sel_main')
            sel_trials = ev.sel_main;
        elseif cfg.sort.exclude_unusable_from_main && isfield(ev, 'sel_unusable')
            sel_trials = ~ev.sel_unusable;
        end
    end

    sel_left  = ismember(trialinfo, cfg.trig.cue_left)  & sel_trials;
    sel_right = ismember(trialinfo, cfg.trig.cue_right) & sel_trials;

    shift_left  = shift < 0;
    shift_right = shift > 0;

    toward_pertime = (mean(shift_left(sel_left,:),1) + ...
                      mean(shift_right(sel_right,:),1)) / 2;
    away_pertime   = (mean(shift_left(sel_right,:),1) + ...
                      mean(shift_right(sel_left,:),1)) / 2;

    GA_to(end+1,:) = smoothdata(toward_pertime,2,'movmean',slideWin_ms) * 1000; %#ok<AGROW>
    GA_aw(end+1,:) = smoothdata(away_pertime,  2,'movmean',slideWin_ms) * 1000; %#ok<AGROW>
    tvec = ds.time;
    subject_used{end+1,1} = subj; %#ok<AGROW>

    fprintf('%s | rate trials L=%d R=%d (exclude_unusable=%d, shift_min=%g%%)\n', ...
        subj, sum(sel_left), sum(sel_right), cfg.sort.exclude_unusable_from_main, cfg.sort.shift_min);
end

out = struct();
out.wide = run_cluster_window(GA_to, GA_aw, tvec, cfg.stats.rate_wide_window, cfg, 'wide');
out.config = struct( ...
    'slideWin_ms', slideWin_ms, ...
    'shift_min', cfg.sort.shift_min, ...
    'exclude_unusable_from_main', cfg.sort.exclude_unusable_from_main, ...
    'wide_window', cfg.stats.rate_wide_window, ...
    'numrandomization', cfg.stats.numrandomization);

plot_fig1b(out.wide, cfg);

save(fullfile(cfg.out_results,'GA_rate_timecourse.mat'), ...
     'GA_to','GA_aw','tvec','out','cfg','subject_used');
fprintf('[r06] Done. Fig 1b + full-window cluster permutation.\n');
end


function R = run_cluster_window(GA_to, GA_aw, tvec, win, cfg, label)
sel_t = tvec >= win(1) & tvec <= win(2);
GA_to_w = GA_to(:,sel_t);
GA_aw_w = GA_aw(:,sel_t);
tvec_w = tvec(sel_t);
N = size(GA_to_w,1);

R = struct();
R.label = label;
R.window = win;
R.GA_to = GA_to_w;
R.GA_aw = GA_aw_w;
R.time = tvec_w;
R.sigMask = false(size(tvec_w));
R.summary = struct('pos',[],'neg',[]);

fprintf('\n>>> Cluster permutation for %s window [%.3f %.3f] s (N=%d)\n', ...
    label, win(1), win(2), N);

if N < 3
    warning('N=%d -- cluster permutation skipped.', N);
    return;
end

if cfg.use_fieldtrip
    cfg.add_fieldtrip();

    data_toward = [];
    data_toward.label = {'rate'};
    data_toward.time = {tvec_w};
    data_toward.dimord = 'rpt_chan_time';
    data_toward.trial = reshape(GA_to_w, [N, 1, numel(tvec_w)]);

    data_away = [];
    data_away.label = {'rate'};
    data_away.time = {tvec_w};
    data_away.dimord = 'rpt_chan_time';
    data_away.trial = reshape(GA_aw_w, [N, 1, numel(tvec_w)]);

    stat_cfg = [];
    stat_cfg.method           = 'montecarlo';
    stat_cfg.statistic        = 'depsamplesT';
    stat_cfg.correctm         = 'cluster';
    stat_cfg.clusteralpha     = 0.05;
    stat_cfg.clusterstatistic = 'maxsum';
    stat_cfg.tail             = 0;
    stat_cfg.alpha            = 0.05;
    stat_cfg.numrandomization = cfg.stats.numrandomization;
    stat_cfg.channel          = {'rate'};
    stat_cfg.neighbours       = [];
    stat_cfg.design = [1:N, 1:N; ones(1,N), 2*ones(1,N)];
    stat_cfg.ivar = 2;
    stat_cfg.uvar = 1;

    stat = ft_timelockstatistics(stat_cfg, data_toward, data_away);
    R.stat = stat;
    R.sigMask = stat.mask(:)';
    R.summary = summarize_fieldtrip_clusters(stat, tvec_w);
else
    helper_out = helper_cluster_perm_1d(GA_to_w, GA_aw_w, ...
        'nPerm', cfg.stats.numrandomization, 'alpha',0.05, 'tail',0);
    R.helper_out = helper_out;
    R.sigMask = helper_out.sigMask;
    R.summary = summarize_helper_clusters(helper_out, tvec_w);
end

print_cluster_summary(R.summary, label);
end


function summary = summarize_fieldtrip_clusters(stat, tvec)
summary = struct('pos',[],'neg',[]);
summary.pos = summarize_ft_side(stat, tvec, 'pos');
summary.neg = summarize_ft_side(stat, tvec, 'neg');
end


function clusters = summarize_ft_side(stat, tvec, side)
clusters = struct('index',{},'prob',{},'clusterstat',{},'start',{},'stop',{},'nTime',{});
clusterField = [side 'clusters'];
labelField = [side 'clusterslabelmat'];
if ~isfield(stat, clusterField) || isempty(stat.(clusterField))
    return;
end
if ~isfield(stat, labelField) || isempty(stat.(labelField))
    return;
end

labelMat = squeeze(stat.(labelField));
for ic = 1:numel(stat.(clusterField))
    mask = labelMat == ic;
    idx = find(mask(:)');
    if isempty(idx)
        continue;
    end
    c = stat.(clusterField)(ic);
    clusters(end+1).index = ic; %#ok<AGROW>
    clusters(end).prob = c.prob;
    if isfield(c, 'clusterstat')
        clusters(end).clusterstat = c.clusterstat;
    else
        clusters(end).clusterstat = NaN;
    end
    clusters(end).start = tvec(idx(1));
    clusters(end).stop = tvec(idx(end));
    clusters(end).nTime = numel(idx);
end
end


function summary = summarize_helper_clusters(helper_out, tvec)
summary = struct('pos',[],'neg',[]);
pos = struct('index',{},'prob',{},'clusterstat',{},'start',{},'stop',{},'nTime',{});
neg = pos;
for ic = 1:numel(helper_out.clusters)
    c = helper_out.clusters(ic);
    entry = struct( ...
        'index', ic, ...
        'prob', c.p, ...
        'clusterstat', c.mass, ...
        'start', tvec(c.start), ...
        'stop', tvec(c.stop), ...
        'nTime', c.stop - c.start + 1);
    if c.mass >= 0
        pos(end+1) = entry; %#ok<AGROW>
    else
        neg(end+1) = entry; %#ok<AGROW>
    end
end
summary.pos = pos;
summary.neg = neg;
end


function print_cluster_summary(summary, label)
fprintf('  %s positive clusters:\n', label);
print_cluster_side(summary.pos);
fprintf('  %s negative clusters:\n', label);
print_cluster_side(summary.neg);
end


function print_cluster_side(clusters)
if isempty(clusters)
    fprintf('    none\n');
    return;
end
for i = 1:numel(clusters)
    sig = '';
    if clusters(i).prob < 0.05
        sig = ' *';
    end
    fprintf('    #%d p=%.4f stat=%.2f t=%.3f..%.3f n=%d%s\n', ...
        clusters(i).index, clusters(i).prob, clusters(i).clusterstat, ...
        clusters(i).start, clusters(i).stop, clusters(i).nTime, sig);
end
end


function plot_fig1b(wide, cfg)
fig = figure('position',[100 100 760 370],'Color','w'); hold on
N = size(wide.GA_to,1);
mTo = mean(wide.GA_to,1,'omitnan');
seTo = std(wide.GA_to,0,1,'omitnan')./sqrt(N) * 1.96;
mAw = mean(wide.GA_aw,1,'omitnan');
seAw = std(wide.GA_aw,0,1,'omitnan')./sqrt(N) * 1.96;

ciTo = fill([wide.time fliplr(wide.time)],[mTo+seTo fliplr(mTo-seTo)],[0.3 0.7 0.3], ...
     'EdgeColor','none','FaceAlpha',0.25);
ciAw = fill([wide.time fliplr(wide.time)],[mAw+seAw fliplr(mAw-seAw)],[0.7 0.4 0.7], ...
     'EdgeColor','none','FaceAlpha',0.25);
lineTo = plot(wide.time, mTo, 'Color',[0.3 0.7 0.3], 'LineWidth',2);
lineAw = plot(wide.time, mAw, 'Color',[0.7 0.4 0.7], 'LineWidth',2);

xline(0,'--k', 'HandleVisibility','off');
xlim(wide.window); xlabel('time after cue (s)'); ylabel('Rate (Hz)');
lgd = legend([ciTo, ciAw, lineTo, lineAw], ...
    {'95% CI Toward','95% CI Away','Toward','Away'}, ...
    'Location','best','box','off');
lgd.AutoUpdate = 'off';

yl = ylim;
plot_sig_segments(wide.time, wide.sigMask, yl(1) + 0.03*diff(yl), 'k', 3);
title(sprintf('Fig 1b | gaze-shift rate (N=%d, shift >= %.1f%%)', N, cfg.sort.shift_min));

saveas(fig, fullfile(cfg.out_figures,'fig1b_rate_timecourse.png'));
fprintf('  Fig 1b saved. Black bars mark significant full-window clusters.\n');
end


function plot_sig_segments(tvec, mask, y, color, lw)
edges = diff([0 mask 0]);
ss = find(edges==1);
ee = find(edges==-1)-1;
for k = 1:numel(ss)
    plot(tvec(ss(k):ee(k)), y*ones(1, ee(k)-ss(k)+1), '-', ...
        'Color', color, 'LineWidth', lw, 'HandleVisibility','off');
end
end
