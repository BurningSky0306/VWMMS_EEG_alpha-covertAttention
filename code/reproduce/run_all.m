function run_all(varargin)
% RUN_ALL  顺序执行整个复现流水线。
%
% 用法:
%   run_all                    % 默认全跑（r01 → r06）
%   run_all('from','r03')      % 从某步开始
%   run_all('only',{'r02','r03'})
%
% 步骤说明：
%   r01  preprocessing                .asc → eye_data.mat
%   r02  microsaccade detection       Fig 1c
%   r03  trial sorting                Fig 1d (toward/away/noMS)
%   r04  link behavior log
%   r05  behavior analysis            Fig 2 + RM-ANOVA + Bonferroni
%   r06  group-rate cluster perm      Fig 1b（论文显著性黑横线）
%
% 注：r02/r03/r05/r06 依赖各自的前置文件。run_all 一次性顺序跑可保证依赖。
% 当 cfg.use_fieldtrip = true 时，r01 使用 ft_redefinetrial 做 epoching，
% r06 使用 ft_timelockstatistics 做 cluster permutation。

p = inputParser;
addParameter(p,'from','r01');
addParameter(p,'only',{});
parse(p,varargin{:});

steps = {'r01_prepare_eye_data', ...
         'r02_detect_microsaccades', ...
         'r03_sort_trials', ...
         'r04_link_behavior', ...
         'r05_behavior_analysis', ...
         'r06_group_rate_clusterperm'};

if ~isempty(p.Results.only)
    keep = false(size(steps));
    for k = 1:numel(p.Results.only)
        keep = keep | startsWith(steps, p.Results.only{k});
    end
    steps = steps(keep);
else
    start_idx = find(startsWith(steps, p.Results.from), 1);
    if isempty(start_idx), error('Unknown start step: %s', p.Results.from); end
    steps = steps(start_idx:end);
end

% 确保 path 含 reproduce 目录
this_dir = fileparts(mfilename('fullpath'));
addpath(this_dir);
addpath(fileparts(this_dir));   % 原作者代码目录

% 加载配置
cfg = r00_setup();

% 当 cfg.use_fieldtrip = true 时，预先加载 FieldTrip 路径
if cfg.use_fieldtrip
    cfg.add_fieldtrip();
end

t_start = tic;
for k = 1:numel(steps)
    fprintf('\n##### %s #####\n', steps{k});
    feval(steps{k});
end
fprintf('\n##### ALL DONE in %.1f s #####\n', toc(t_start));
end
