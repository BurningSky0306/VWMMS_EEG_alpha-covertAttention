function r04_link_behavior()
% R04_LINK_BEHAVIOR
% 把行为 log (.txt) 与 eye trial 一一对齐，并按论文 Methods 做修剪：
%   - RT 修剪：>3000 ms 剔除 + 2.5 SD 截断（per subject）
%   - 主要列：error = |reportVsTarget|, RT = RT1 (cue → 报告启动)
%
% 输入: data/exp1_sessN_log/sNN_vm_*.txt  (每 session 一份)
% 输出: behavior_aligned/sNN.mat 含表 behavior:
%   .block .trial .session .RT .error .targetLoc .reportOri ...
% 行数严格 = sess1 行数 + sess2 行数 = eye_data 中的 trial 数（应一致）
%
% 论文行为 log 列含义（实验程序 Presentation 输出）：
%   targetLoc:     1 = 左, 2 = 右（被 cue 选中的那个 memory item 在 encoding 时的位置）
%   reportVsTarget: 报告 - 真实 orientation （signed degrees）
%   RT1: 自 cue onset 到按键 onset
%   RT2: 自 cue onset 到松键
%   RT3: 自报告 dial 出现到松键
%
% 论文 Fig 2 用的:
%   - error = |reportVsTarget|
%   - RT    = RT1（cue → response onset，与 paper 一致）

cfg = r00_setup();

for is = 1:numel(cfg.subj)
    subj = cfg.subj{is};
    fprintf('\nLinking behavior for %s...\n', subj);

    parts = {};
    for sess = 1:2
        % 文件名形如 s01_vm_DDMMYYYY.txt（sess2 带 'b' 后缀: s01b_vm_*.txt）
        if sess == 1, base = subj; else, base = [subj 'b']; end
        files = dir(fullfile(cfg.data_log{sess}, [base '_vm_*.txt']));
        if isempty(files)
            warning('No log file for %s sess %d', subj, sess); continue;
        end
        log_file = fullfile(cfg.data_log{sess}, files(1).name);
        T = readtable(log_file, 'FileType','text', 'Delimiter','\t', ...
                      'ReadVariableNames', true);
        T.session = repmat(sess, height(T), 1);
        parts{end+1} = T; %#ok<AGROW>
    end
    if isempty(parts), continue; end
    BeAll = vertcat(parts{:});

    % --- 与 eye_data 对齐 ---
    eye_file = fullfile(cfg.out_eye, [subj '.mat']);
    if ~exist(eye_file,'file')
        warning('Run r01 first.'); continue;
    end
    Es = load(eye_file); ntrl_eye = size(Es.eye_data.trial, 1);
    if height(BeAll) ~= ntrl_eye
        warning(['%s: behavior rows (%d) ≠ eye trials (%d). ' ...
                 '可能因 epoch 越界丢 trial。需检查。下面以 eye 为准截断。'], ...
                 subj, height(BeAll), ntrl_eye);
        % 简单策略：以较小者为准，截尾
        n = min(height(BeAll), ntrl_eye);
        BeAll = BeAll(1:n,:);
    end

    % --- 计算分析变量 ---
    behavior = table();
    behavior.session   = BeAll.session;
    behavior.block     = BeAll.block;
    behavior.trial     = BeAll.trial;
    behavior.targetLoc = BeAll.targetLoc;       % 1=L, 2=R
    behavior.RT        = BeAll.RT1;             % cue→response onset
    behavior.error     = abs(BeAll.reportVsTarget);
    behavior.reportVsTarget = BeAll.reportVsTarget;

    % --- 修剪 RT (论文 Methods) ---
    rt = behavior.RT;
    valid = rt <= 3000;                                     % 步骤 1
    mu = mean(rt(valid),'omitnan'); sd = std(rt(valid),'omitnan');
    valid = valid & abs(rt-mu) <= 2.5*sd;                   % 步骤 2: 2.5 SD
    behavior.valid_RT = valid;

    fprintf('  %s: %d trials total, %d retained after RT trim (%d > 3000 ms, %d outside 2.5SD)\n',...
        subj, numel(rt), sum(valid), sum(rt>3000), sum(~valid)-sum(rt>3000));

    save(fullfile(cfg.out_beh, [subj '.mat']), 'behavior');
end
fprintf('[r04] Done. Behavior linkage.\n');
end
