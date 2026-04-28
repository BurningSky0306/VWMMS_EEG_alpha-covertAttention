function out = helper_cluster_perm_1d(A, B, varargin)
% HELPER_CLUSTER_PERM_1D
% 1D cluster-based permutation test (Maris & Oostenveld, 2007) for paired
% data. 适合"toward vs away"这种被试内、跨时间的对比。
%
% 用法:
%   out = helper_cluster_perm_1d(A, B)
%   out = helper_cluster_perm_1d(A, B, 'nPerm',10000, 'alpha',0.05, 'tail',0)
%
% A, B: [N_subjects x N_timepoints]   配对数据
% 可选参数:
%   'nPerm'    permutation 次数 (默认 10000)
%   'alpha'    cluster-defining 阈值 (默认 0.05)，用 t 分布临界
%   'tail'     0 = 双侧 (默认), 1 = 仅正, -1 = 仅负
%
% 输出 out:
%   .clusters    struct array, 每个含 .start .stop .mass(t-sum) .p
%   .sigMask     [1 x T] logical, 显著时间点
%   .tvals       [1 x T] 原始配对 t 值
%
% Reproduce pipeline | 2026

p = inputParser;
addParameter(p,'nPerm',10000);
addParameter(p,'alpha',0.05);
addParameter(p,'tail',0);
parse(p, varargin{:});
nPerm = p.Results.nPerm;
alpha = p.Results.alpha;
tail  = p.Results.tail;

[N, T] = size(A);
assert(all(size(B)==[N T]), 'A and B must have same size');
D = A - B;                          % 配对差

% --- 原始 t 值 + cluster ---
tvals = sqrt(N) .* mean(D,1,'omitnan') ./ std(D,0,1,'omitnan');
tcrit = abs(tinv(alpha/2, N-1));    % 双侧临界
[obs_clusters, obs_mass] = find_clusters(tvals, tcrit, tail);

if isempty(obs_clusters)
    out.clusters = struct('start',{},'stop',{},'mass',{},'p',{});
    out.sigMask  = false(1,T);
    out.tvals    = tvals;
    return;
end

% --- Permutation: 每次翻转随机被试的差值符号 ---
maxMass = nan(nPerm,1);
for ip = 1:nPerm
    flip = (rand(N,1) < 0.5) * 2 - 1;       % ±1
    Dperm = D .* flip;
    tperm = sqrt(N) .* mean(Dperm,1,'omitnan') ./ std(Dperm,0,1,'omitnan');
    [~, masses] = find_clusters(tperm, tcrit, tail);
    if isempty(masses), maxMass(ip) = 0;
    else,               maxMass(ip) = max(abs(masses));
    end
end

% --- 每个原始 cluster 计 p ---
clusters = struct('start',{},'stop',{},'mass',{},'p',{});
sigMask = false(1, T);
for ic = 1:numel(obs_clusters)
    c = obs_clusters(ic);
    pval = mean(maxMass >= abs(obs_mass(ic)));
    clusters(ic).start = c(1);
    clusters(ic).stop  = c(2);
    clusters(ic).mass  = obs_mass(ic);
    clusters(ic).p     = pval;
    if pval < alpha
        sigMask(c(1):c(2)) = true;
    end
end

out.clusters = clusters;
out.sigMask  = sigMask;
out.tvals    = tvals;
end


function [clusters, masses] = find_clusters(tvals, tcrit, tail)
% 把超阈值的相邻同号 t 值聚成簇；返回每簇 [start stop] 与 t-mass
above = false(size(tvals));
switch tail
    case 0,  above = abs(tvals) >= tcrit;
    case 1,  above = tvals >= tcrit;
    case -1, above = tvals <= -tcrit;
end
% 进一步按符号切（同号的相邻才算一簇）
edges = diff([0 above 0]);
starts = find(edges == 1);
ends   = find(edges == -1) - 1;

clusters = {}; masses = [];
for k = 1:numel(starts)
    seg = starts(k):ends(k);
    % 按符号切子段
    s = seg(1);
    while s <= seg(end)
        sgn = sign(tvals(s));
        e = s;
        while e+1 <= seg(end) && sign(tvals(e+1)) == sgn
            e = e+1;
        end
        clusters{end+1} = [s e]; %#ok<AGROW>
        masses(end+1)   = sum(tvals(s:e)); %#ok<AGROW>
        s = e + 1;
    end
end
end
