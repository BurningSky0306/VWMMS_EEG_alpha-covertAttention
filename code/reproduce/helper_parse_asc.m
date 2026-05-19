function out = helper_parse_asc(asc_file)
% HELPER_PARSE_ASC  解析 EyeLink ASC 文件，提取双眼 gaze 样本与所有 MSG trigger。
%
% 不依赖 FieldTrip——直接文本解析以避免版本差异。
%
% 输入: asc_file  完整路径
% 输出 out 结构:
%   .Fs            采样率 (Hz)
%   .t             [1 x Nsamp] 时间戳 (ms, EyeLink 原生)
%   .LX,.LY        左眼 X,Y 像素 (NaN = 缺失)
%   .RX,.RY        右眼 X,Y 像素 (NaN = 缺失)
%   .trig_code     [Ntrig x 1] trigger 数字编码
%   .trig_time     [Ntrig x 1] trigger 时间戳 (ms, 与 .t 同坐标系)
%   .display       屏幕分辨率 [w h]
%
% 假设单眼记录: 数据行 = time LX LY Lpup; 只有 LX/LY 有效。
% 双眼记录:    数据行 = time LX LY Lpup RX RY Rpup。
% 缺失值用 '.' 表示 → 转 NaN。
%
% Reproduce pipeline | 2026

fid = fopen(asc_file, 'r');
if fid < 0, error('Cannot open %s', asc_file); end
clean = onCleanup(@() fclose(fid));

% 预分配（按文件字节估算，1 行 ~50 字节）
fileinfo = dir(asc_file);
est_lines = max(round(fileinfo.bytes/50), 1e5);

t   = nan(est_lines,1);
LX  = nan(est_lines,1);
LY  = nan(est_lines,1);
RX  = nan(est_lines,1);
RY  = nan(est_lines,1);
trig_code = nan(est_lines,1);
trig_time = nan(est_lines,1);

isamp = 0;
itrig = 0;
Fs = 1000;          % 缺省，遇到 SAMPLES 行后覆盖
display_res = [1920 1080];
binocular = NaN;    % 待数据行第一次出现时确定
fast_required_numeric = NaN;

while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line) || isempty(line), continue; end

    % --- MSG 事件（trigger） ---
    if length(line) >= 3 && strcmp(line(1:3),'MSG')
        % 形如: MSG\t<timestamp> trig<code>
        toks = regexp(line, '^MSG\s+(\d+)\s+trig(\d+)', 'tokens', 'once');
        if ~isempty(toks)
            itrig = itrig + 1;
            trig_time(itrig) = str2double(toks{1});
            trig_code(itrig) = str2double(toks{2});
            continue;
        end
        % 解析 RECCFG 行获取采样率（可选）
        rec = regexp(line, 'RECCFG\s+\w+\s+(\d+)', 'tokens', 'once');
        if ~isempty(rec)
            Fs = str2double(rec{1});
        end
        % 解析屏幕分辨率
        dco = regexp(line, 'DISPLAY_COORDS\s+\d+\s+\d+\s+(\d+)\s+(\d+)', 'tokens', 'once');
        if ~isempty(dco)
            display_res = [str2double(dco{1})+1, str2double(dco{2})+1];
        end
        continue;
    end

    % --- 数据样本行 ---
    % 行首是数字（时间戳）。EyeLink ASC 数据行示例:
    %   3733597	 1218.7	  592.1	 8463.0	 1254.0	  527.2	 8614.0	.....
    % 缺失字段显示为 '.'（单点），需替换为 NaN。
    if line(1) >= '0' && line(1) <= '9'
        % 数据列数: 单眼 = 1 + 3 = 4 列；双眼 = 1 + 6 = 7 列。
        % 第 1 列时间戳；后续 status 字段非数字。
        % 自动检测：取前 4 或 7 个看哪个全是 number-like
        if isnan(binocular)
            % 首个数据行只做一次 token 解析，用于兼容该行含 '.' 的情况。
            toks = regexp(line, '\S+', 'match');
            % 尝试解析前 7 个为数字
            ncol = 0;
            for k = 1:min(7, numel(toks))
                v = toks{k};
                if all(ismember(v, '0123456789.-'))
                    ncol = k;
                else
                    break;
                end
            end
            binocular = (ncol >= 7);
            fast_required_numeric = 4 + 3*binocular;  % 单眼=4, 双眼=7；不足时走兼容慢路径
            [ok, tv, lxv, lyv, rxv, ryv] = parseSampleTokens(toks, binocular);
        else
            % 热路径：绝大多数样本行没有缺失 '.', sscanf 避免逐行 regexp+str2double。
            vals = sscanf(line, '%f', 7);
            ok = numel(vals) >= fast_required_numeric;
            if ok
                tv  = vals(1);
                lxv = vals(2);
                lyv = vals(3);
                if binocular
                    rxv = vals(5);
                    ryv = vals(6);
                else
                    rxv = NaN;
                    ryv = NaN;
                end
            else
                toks = regexp(line, '\S+', 'match');
                [ok, tv, lxv, lyv, rxv, ryv] = parseSampleTokens(toks, binocular);
            end
        end
        if ~ok, continue; end

        isamp = isamp + 1;
        t(isamp)  = tv;
        LX(isamp) = lxv;
        LY(isamp) = lyv;
        if binocular
            RX(isamp) = rxv;
            RY(isamp) = ryv;
        end
    end
end

% 截到实际长度
t  = t(1:isamp);
LX = LX(1:isamp); LY = LY(1:isamp);
RX = RX(1:isamp); RY = RY(1:isamp);
trig_code = trig_code(1:itrig);
trig_time = trig_time(1:itrig);

out.Fs = Fs;
out.t  = t;
out.LX = LX; out.LY = LY;
out.RX = RX; out.RY = RY;
out.trig_code = trig_code;
out.trig_time = trig_time;
out.display   = display_res;
out.binocular = logical(binocular);
end

function v = parseDot(s)
% 将 '.' 或 '...' 等缺失值转 NaN，否则 str2double
if isempty(s) || s(1) == '.', v = NaN;
else, v = str2double(s);
end
end

function [ok, tv, lxv, lyv, rxv, ryv] = parseSampleTokens(toks, binocular)
% 慢路径：只在首行检测或样本行含 '.' 时使用，保持旧解析器对缺失值的兼容。
tv = NaN; lxv = NaN; lyv = NaN; rxv = NaN; ryv = NaN;
nfields = 4;
if binocular, nfields = 7; end
ok = numel(toks) >= nfields;
if ~ok, return; end

tv  = str2double(toks{1});
lxv = parseDot(toks{2});
lyv = parseDot(toks{3});
if binocular
    rxv = parseDot(toks{5});
    ryv = parseDot(toks{6});
end
end
