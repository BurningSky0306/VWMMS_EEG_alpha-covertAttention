% VERIFY_PARSE_ASC  手动抽查原始 ASC 文本 vs helper_parse_asc 输出
%
% 不依赖 FieldTrip，直接读文件头几行 + 数据行，和解析器结果对比。

repo_root = 'C:\MATLABEMM\MATLABWorkspaceEMM\VWMMS_EEG_alpha-covertAttention';
addpath(fullfile(repo_root, 'code', 'reproduce'));
asc = fullfile(repo_root, 'data','exp1_sess1_eye','s01_vm.asc');
if ~exist(asc,'file'), error('找不到 %s', asc); end

fprintf('=== 解析 %s ===\n\n', asc);
out = helper_parse_asc(asc);

% ============================================================
% 1. 读取原始文件前 200 行，分类展示
% ============================================================
fid = fopen(asc, 'r');
raw_lines = {};
while ~feof(fid) && numel(raw_lines) < 200
    raw_lines{end+1} = fgetl(fid); %#ok<AGROW>
end
fclose(fid);

msg_lines = {};
data_lines = {};
for i = 1:numel(raw_lines)
    L = raw_lines{i};
    if ~ischar(L) || isempty(L), continue; end
    if length(L) >= 3 && strcmp(L(1:3), 'MSG')
        msg_lines{end+1} = L; %#ok<AGROW>
    elseif L(1) >= '0' && L(1) <= '9'
        data_lines{end+1} = L; %#ok<AGROW>
    end
end

fprintf('--- 原始文件前 200 行统计 ---\n');
fprintf('MSG 行: %d\n', numel(msg_lines));
fprintf('数据行: %d\n', numel(data_lines));

% ============================================================
% 2. 验证 MSG 事件
% ============================================================
fprintf('\n--- MSG 事件抽查 ---\n');
trig_count = 0;
for i = 1:numel(msg_lines)
    toks = regexp(msg_lines{i}, '^MSG\s+(\d+)\s+trig(\d+)', 'tokens', 'once');
    if isempty(toks), continue; end
    trig_count = trig_count + 1;
    raw_time = str2double(toks{1});
    raw_code = str2double(toks{2});

    if trig_count <= numel(out.trig_code)
        time_ok = (raw_time == out.trig_time(trig_count));
        code_ok = (raw_code == out.trig_code(trig_count));
        status = iff(time_ok && code_ok, 'PASS', 'FAIL');
        fprintf('  trig #%d: raw=(%d, %d) parsed=(%d, %d) [%s]\n', ...
            trig_count, raw_code, raw_time, out.trig_code(trig_count), out.trig_time(trig_count), status);
    end
end
fprintf('原始 MSG 中 trig 数: %d, 解析器输出: %d [%s]\n', ...
    trig_count, numel(out.trig_code), iff(trig_count <= numel(out.trig_code), 'PASS', 'CHECK'));

% ============================================================
% 3. 验证数据行
% ============================================================
fprintf('\n--- 数据行抽查 (前 5 行) ---\n');
for i = 1:min(5, numel(data_lines))
    toks = regexp(data_lines{i}, '\S+', 'match');
    raw_time = str2double(toks{1});
    raw_LX = parse_dot(toks{2});
    raw_LY = parse_dot(toks{3});

    % 在 out.t 中找对应时间戳
    idx = find(out.t == raw_time, 1);
    if isempty(idx)
        fprintf('  行%d: time=%d — 在 out.t 中未找到精确匹配\n', i, raw_time);
        continue;
    end

    lx_ok = compare_val(raw_LX, out.LX(idx));
    ly_ok = compare_val(raw_LY, out.LY(idx));
    fprintf('  行%d: time=%d idx=%d LX(raw=%.1f, parsed=%.1f %s) LY(raw=%.1f, parsed=%.1f %s)\n', ...
        i, raw_time, idx, raw_LX, out.LX(idx), iff(lx_ok,'OK','FAIL'), ...
        raw_LY, out.LY(idx), iff(ly_ok,'OK','FAIL'));
end

% ============================================================
% 4. 验证缺失值 (.) → NaN
% ============================================================
fprintf('\n--- 缺失值验证 ---\n');
dot_count = 0;
nan_match = 0;
nan_mismatch = 0;
for i = 1:min(500, numel(data_lines))
    toks = regexp(data_lines{i}, '\S+', 'match');
    raw_time = str2double(toks{1});
    idx = find(out.t == raw_time, 1);
    if isempty(idx), continue; end

    if numel(toks) >= 2
        is_dot = (toks{2}(1) == '.');
        is_nan = isnan(out.LX(idx));
        if is_dot
            dot_count = dot_count + 1;
            if is_nan, nan_match = nan_match + 1;
            else, nan_mismatch = nan_mismatch + 1; end
        end
    end
end
fprintf('前 500 行中 LX=. 的行: %d, 对应 NaN: %d, 不匹配: %d [%s]\n', ...
    dot_count, nan_match, nan_mismatch, iff(nan_mismatch==0, 'PASS', 'FAIL'));

% ============================================================
% 5. 采样率验证
% ============================================================
fprintf('\n--- 采样率验证 ---\n');
% 从数据行的时间戳间隔推断 Fs
if numel(data_lines) >= 100
    t1 = str2double(regexp(data_lines{1}, '\S+', 'match', 'once'));
    t100 = str2double(regexp(data_lines{100}, '\S+', 'match', 'once'));
    dt = (t100 - t1) / 99;
    inferred_Fs = round(1000 / dt);
    fprintf('前 100 行时间间隔: %.3f ms → 推断 Fs=%d Hz, 解析器 Fs=%d [%s]\n', ...
        dt, inferred_Fs, out.Fs, iff(inferred_Fs == out.Fs, 'PASS', 'FAIL'));
end

% ============================================================
% 6. 双眼检测验证
% ============================================================
fprintf('\n--- 双眼检测验证 ---\n');
% 检查数据行的 token 数
ncols = zeros(min(10, numel(data_lines)), 1);
for i = 1:min(10, numel(data_lines))
    ncols(i) = numel(regexp(data_lines{i}, '\S+', 'match'));
end
max_nc = max(ncols);
detected_binocular = (max_nc >= 7);
fprintf('数据行列数: %s (max=%d), 解析器 binocular=%d [%s]\n', ...
    mat2str(ncols'), max_nc, out.binocular, ...
    iff(detected_binocular == out.binocular, 'PASS', 'FAIL'));

% ============================================================
% 7. 总体统计
% ============================================================
fprintf('\n--- 总体统计 ---\n');
fprintf('总样本数: %d\n', numel(out.t));
fprintf('总事件数: %d\n', numel(out.trig_code));
fprintf('LX NaN 比例: %.1f%%\n', 100*mean(isnan(out.LX)));
fprintf('LY NaN 比例: %.1f%%\n', 100*mean(isnan(out.LY)));
fprintf('LX 范围: [%.1f, %.1f] px\n', min(out.LX,[],'omitnan'), max(out.LX,[],'omitnan'));
fprintf('LY 范围: [%.1f, %.1f] px\n', min(out.LY,[],'omitnan'), max(out.LY,[],'omitnan'));
if out.binocular
    fprintf('RX NaN 比例: %.1f%%\n', 100*mean(isnan(out.RX)));
    fprintf('RX 范围: [%.1f, %.1f] px\n', min(out.RX,[],'omitnan'), max(out.RX,[],'omitnan'));
end

fprintf('\n=== 验证完成 ===\n');

function s = iff(cond, a, b)
    if cond, s = a; else, s = b; end
end

function v = parse_dot(s)
    if isempty(s) || s(1) == '.', v = NaN;
    else, v = str2double(s);
    end
end

function ok = compare_val(a, b)
    if isnan(a), ok = isnan(b);
    else, ok = abs(a - b) < 0.01;
    end
end
