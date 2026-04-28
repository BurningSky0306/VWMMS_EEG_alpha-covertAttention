function r02_detect_microsaccades()
% R02_DETECT_MICROSACCADES
% 调用原作者的 PBlab_gazepos2shift_1D 进行微眼跳检测，
% 然后调用 gazeShiftRateOverSize 出 Fig 1c (rate × size × time)。
%
% 与原 get_saccadeEvent.m 的区别：
%   - 不依赖原作者的 Mac 路径
%   - 使用 r00_setup 配置
%   - 把每个被试的 shift 数据存到 cfg.out_shift
%   - 跨被试聚合后存到 cfg.out_results/GA_shift_rateAndsize.mat
%   - 出图保存到 cfg.out_figures
%
% Reproduce pipeline | 2026

cfg = r00_setup();

eye_files = arrayfun(@(s) fullfile(cfg.out_eye, [s{1} '.mat']), cfg.subj, 'UniformOutput', false);

% ===== 单被试微眼跳检测 =====
for is = 1:numel(eye_files)
    if ~exist(eye_files{is},'file')
        warning('Missing %s — run r01 first.', eye_files{is}); continue;
    end
    fprintf('Detecting microsaccades for %s...\n', cfg.subj{is});
    S = load(eye_files{is});
    eye_data = S.eye_data;

    eye_dataX = squeeze(eye_data.trial(:,1,:));   % X 通道 [ntrl x ntime]

    detect_cfg = [];
    detect_cfg.threshold   = cfg.detect.threshold;
    detect_cfg.smooth_step = cfg.detect.smooth_step;
    detect_cfg.minISI      = cfg.detect.minISI;
    detect_cfg.winbef      = cfg.detect.winbef;
    detect_cfg.winaft      = cfg.detect.winaft;

    [eye_shift, time_shift] = PBlab_gazepos2shift_1D(detect_cfg, eye_dataX, eye_data.time);

    data_shift = [];
    data_shift.shift     = eye_shift;
    data_shift.time      = time_shift;
    data_shift.trialinfo = eye_data.trialinfo;

    save(fullfile(cfg.out_shift, [cfg.subj{is} '.mat']), 'data_shift');
end

% ===== 跨被试 rate × size 聚合 (Fig 1c) =====
fprintf('\nComputing rate × size aggregate (Fig 1c)...\n');
GA_struct = struct('toward',[],'away',[],'diff',[]);

for is = 1:numel(cfg.subj)
    shift_file = fullfile(cfg.out_shift, [cfg.subj{is} '.mat']);
    if ~exist(shift_file,'file'), continue; end
    S = load(shift_file); data_shift = S.data_shift;

    rs_cfg = [];
    rs_cfg.size_range  = [1 110];
    rs_cfg.binWin      = 5;
    rs_cfg.binstep     = 1;
    rs_cfg.trigs_left  = cfg.trig.cue_left;
    rs_cfg.trigs_right = cfg.trig.cue_right;

    [rate_size, bin_range] = gazeShiftRateOverSize(rs_cfg, data_shift.shift, data_shift.trialinfo);

    GA_struct.toward(is,:,:) = rate_size.toward;
    GA_struct.away  (is,:,:) = rate_size.away;
    GA_struct.diff  (is,:,:) = rate_size.diff;
end
GA_struct.bin_range = bin_range;
GA_struct.time      = data_shift.time;
save(fullfile(cfg.out_results, 'GA_shift_rateAndsize.mat'), 'GA_struct');

% ===== 绘 Fig 1c =====
plot_fig1c(GA_struct, cfg);

fprintf('[r02] Done. Microsaccade detection + Fig 1c.\n');
end


function plot_fig1c(GA, cfg)
% Fig 1c: 三联图 toward / away / diff
try
    cmap = brewermap([], '*RdBu');
catch
    warning('brewermap not on path; falling back to parula. addpath ColorBrewer to enable.');
    cmap = parula(256);
end

xli = [-0.2 1];
fig = figure('position', [100 100 1200 320], 'Color', 'w');

% Difference
subplot(1,3,1)
hz = squeeze(mean(GA.diff,1,'omitnan'));
contourf(GA.time, GA.bin_range, hz, 50, 'linecolor','none')
mv = max(abs(hz(:)));
caxis([-mv mv]); colorbar; colormap(cmap);
xlabel('time (s)'); ylabel('shift size (%)');
title('Toward − Away'); hold on
plot([0 0],[GA.bin_range(1) GA.bin_range(end)],'--k')
plot(xli,[100/5.7 100/5.7],'--k')      % 1° reference (~17.5%)
plot(xli,[100 100],'--k')              % 5.7° reference (=100%)
xlim(xli)

% Toward
subplot(1,3,2)
hz_to = squeeze(mean(GA.toward,1,'omitnan'));
hz_aw = squeeze(mean(GA.away,1,'omitnan'));
mv = max([max(hz_to(:)) max(hz_aw(:))]);
contourf(GA.time, GA.bin_range, hz_to, 50, 'linecolor','none')
caxis([-mv mv]); colorbar; colormap(cmap);
xlabel('time (s)'); ylabel('shift size (%)'); title('Toward'); hold on
plot([0 0],[GA.bin_range(1) GA.bin_range(end)],'--k')
xlim(xli)

% Away
subplot(1,3,3)
contourf(GA.time, GA.bin_range, hz_aw, 50, 'linecolor','none')
caxis([-mv mv]); colorbar; colormap(cmap);
xlabel('time (s)'); ylabel('shift size (%)'); title('Away'); hold on
plot([0 0],[GA.bin_range(1) GA.bin_range(end)],'--k')
xlim(xli)

sgtitle(sprintf('Fig 1c | rate × size × time (N=%d)', size(GA.diff,1)));

saveas(fig, fullfile(cfg.out_figures, 'fig1c_rate_size_time.png'));
fprintf('  Fig 1c saved to %s\n', fullfile(cfg.out_figures, 'fig1c_rate_size_time.png'));
end
