# EyeLink .asc 文件字段完整说明

> 数据来源：EyeLink II 眼动仪，由 `edfapi` 从 `.edf` 转换为 `.asc` 纯文本格式
> 采样率：1000 Hz，双眼记录（L+R），CR（角膜反射）追踪模式

---

## 一、文件头（`**` 注释行）

| 行 | 含义 |
|---|---|
| `** CONVERTED FROM ... edfapi 3.1` | 转换来源：由 `edfapi` 工具从 `.edf` 转换而来 |
| `** DATE` | 实验采集的日期和时间 |
| `** TYPE: EDF_FILE BINARY EVENT SAMPLE TAGGED` | 文件类型：包含事件、采样点、标签 |
| `** VERSION: EYELINK II 1` | 眼动仪硬件型号 |
| `** SOURCE: EYELINK CL` | 记录来源（CL = Camera Link，摄像头模式） |
| `** EYELINK II CL v5.01` | 固件版本号 |
| `** CAMERA: Eyelink GL Version 1.2 Sensor=AJ7` | 摄像头型号和传感器编号 |
| `** SERIAL NUMBER: CLG-BAF45` | 设备序列号 |
| `** CAMERA_CONFIG: BAF45200.SCD` | 摄像头配置文件名 |

---

## 二、配置行（`MSG` 开头，记录开始前的系统设置）

| 行 | 含义 |
|---|---|
| `MSG <time> DISPLAY_COORDS 0 0 1920 1080` | 屏幕像素坐标范围：左上(0,0) -> 右下(1920,1080) |
| `MSG <time> RECCFG CR 1000 2 1 LR` | 记录配置：CR（角膜反射追踪模式）、**1000 Hz** 采样率、2 通道、双眼 L+R |
| `MSG <time> ELCLCFG BTABLER` | 校准模式（BTABLER = 标准校准方案） |
| `MSG <time> GAZE_COORDS 0.00 0.00 1920.00 1080.00` | 视线映射的坐标范围 |
| `MSG <time> THRESHOLDS L 62 218 R 68 255` | 瞳孔检测阈值：左眼(黑阈62, 白阈218)、右眼(68, 255) |
| `MSG <time> ELCL_WINDOW_SIZES 160 160 0 0` | 瞳孔搜索窗口大小 |
| `MSG <time> ELCL_PROC ELLIPSE (5)` | 瞳孔拟合方法：**椭圆拟合**，5 点校准 |
| `MSG <time> ELCL_EFIT_PARAMS 1.01 4.00 0.15 0.05 0.65 0.65 0.00 0.00 0.30` | 椭圆拟合的内部参数 |
| `MSG <time> !MODE RECORD CR 1000 2 1 LR` | 确认进入记录模式 |

---

## 三、记录边界行

| 行 | 含义 |
|---|---|
| `START <time> LEFT RIGHT SAMPLES EVENTS` | **记录开始**，标记双眼采样和事件记录的起始时间 |
| `END <time> SAMPLES EVENTS RES 60.54 46.87` | **记录结束**，`RES` 后的数值是屏幕分辨率（像素/度） |
| `INPUT <time> 127` | 并行输入端口状态（127 = 端口全高，通常与外部设备同步有关） |

---

## 四、格式声明行

| 行 | 含义 |
|---|---|
| `PRESCALER 1` | 时间预分频系数（1 = 无缩放，时间戳单位 ms） |
| `VPRESCALER 1` | 速度预分频系数（1 = 无缩放） |
| `PUPIL DIAMETER` | 瞳孔测量模式：**直径**（另一选项是 AREA 面积） |
| `EVENTS GAZE LEFT RIGHT RATE 1000.00 TRACKING CR FILTER 2` | 事件格式声明：记录双眼视线坐标、1000 Hz、CR 追踪、滤波等级 2 |
| `SAMPLES GAZE LEFT RIGHT RATE 1000.00 TRACKING CR FILTER 2` | 采样格式声明（同上，针对采样数据行） |

---

## 五、采样数据行（每毫秒一行，数值开头）

```
3741700  900.4  501.3  8679.0  946.5  490.5  8970.0  .....
```

| 列 | 含义 | 单位 |
|---|---|---|
| 第 1 列 | **时间戳**（从记录开始算的毫秒数） | ms |
| 第 2 列 | **左眼 X**（视线在屏幕上的水平坐标） | pixels |
| 第 3 列 | **左眼 Y**（视线在屏幕上的垂直坐标） | pixels |
| 第 4 列 | **左眼瞳孔大小** | arbitrary units |
| 第 5 列 | **右眼 X** | pixels |
| 第 6 列 | **右眼 Y** | pixels |
| 第 7 列 | **右眼瞳孔大小** | arbitrary units |
| 第 8 列起 | **标记位**（每个字符代表一种状态，见下表） | -- |

### 标记位字符含义

| 字符 | 含义 |
|---|---|
| `.` | 正常（无特殊事件） |
| `C` | CR（角膜反射）丢失 |
| `F` | 瞳孔拟合失败（gaze 数据不可靠） |

> 6 个标记位分别对应：左 X、左 Y、左瞳孔、右 X、右 Y、右瞳孔的数据质量。
> 当前复现代码的 `helper_parse_asc.m` 不解析第 8 列起的状态标记，也不读取瞳孔大小作为输出；它只提取时间戳、左/右眼 X/Y、`MSG trigXX`、`RECCFG` 和 `DISPLAY_COORDS`。常规纯数字样本行走 `sscanf(line, '%f', 7)` 快路径；如果必需的前 4/7 个字段里出现 `.` 缺失值或列数异常，则回退到 token 解析，并把 `.` 转成 NaN。

---

## 六、事件行（`MSG` -- 实验软件发送的 trigger）

### 系统/配置类 MSG

| MSG 关键字 | 含义 |
|---|---|
| `DISPLAY_COORDS` | 屏幕分辨率 |
| `RECCFG` | 记录配置 |
| `GAZE_COORDS` | 视线坐标范围 |
| `THRESHOLDS` | 瞳孔检测阈值 |
| `ELCLCFG` | 校准模式 |
| `ELCL_PROC` | 瞳孔拟合方法 |
| `ELCL_EFIT_PARAMS` | 拟合参数 |
| `ELCL_WINDOW_SIZES` | 搜索窗口 |
| `!MODE RECORD` | 进入记录模式 |

### 实验 trigger（`trigXX`）

| Trigger | 含义 | 类别 |
|---|---|---|
| `trig249` | 实验开始 | 标记 |
| `trig250` | 实验结束 | 标记 |
| `trig21` | retro-cue：**左侧**注意（条件 1） | cue |
| `trig22` | retro-cue：**左侧**注意（条件 2） | cue |
| `trig23` | retro-cue：**右侧**注意（条件 1） | cue |
| `trig24` | retro-cue：**右侧**注意（条件 2） | cue |
| `trig1`--`trig4` | trial 内其他事件标记（编码方案由 Presentation 脚本定义） | trial 事件 |
| `trig41`--`trig48` | probe 出现 / 刺激变化等 | trial 事件 |
| `trig61`--`trig68` | 反应阶段标记 | trial 事件 |
| `trig211` | trial 结束（正确试次） | trial 结束 |
| `trig212` | trial 结束（另一条件） | trial 结束 |
| `trig201` | 校准点 1 | 校准 |
| `trig203`--`trig209` | 校准点 3--7（共 7 个校准点） | 校准 |

> `trig21`--`trig24` 是复现分析的核心 trigger，对应论文中的 cue 方向（左/右 x 两种条件）。
> `trig201`/`trig203`--`trig209` 是 r01 做校准归一化时使用的校准点标记。

---

## 七、EyeLink 自动检测的事件行

### SFIX / EFIX -- 注视（Fixation）

| 行 | 格式 | 含义 |
|---|---|---|
| `SFIX L 3733604` | `SFIX <眼别> <起始时间>` | **注视开始**（左眼，时间戳 3733604） |
| `EFIX R 3733723 3733751 29 1253.9 488.5 8883` | 见下 | **注视结束**，包含完整统计信息 |

EFIX 各字段：

| 字段 | 含义 |
|---|---|
| `3733723` | 起始时间 (ms) |
| `3733751` | 结束时间 (ms) |
| `29` | 持续时间 (ms) |
| `1253.9` | 注视期间平均 X (pixels) |
| `488.5` | 注视期间平均 Y (pixels) |
| `8883` | 注视期间平均瞳孔大小 |

### SSACC / ESACC -- 眼跳（Saccade）

| 行 | 格式 | 含义 |
|---|---|---|
| `SSACC L 3733868` | `SSACC <眼别> <起始时间>` | **眼跳开始** |
| `ESACC L 3733868 3733920 53 1222.7 596.8 1014.1 528.4 3.78 350` | 见下 | **眼跳结束** |

ESACC 各字段：

| 字段 | 含义 |
|---|---|
| `3733868` | 起始时间 (ms) |
| `3733920` | 结束时间 (ms) |
| `53` | 持续时间 (ms) |
| `1222.7` | 起始 X (pixels) |
| `596.8` | 起始 Y (pixels) |
| `1014.1` | 结束 X (pixels) |
| `528.4` | 结束 Y (pixels) |
| `3.78` | 眼跳幅度 (degrees) |
| `350` | 峰值速度 (degrees/s) |

### SBLINK / EBLINK -- 眨眼（Blink）

| 行 | 格式 | 含义 |
|---|---|---|
| `SBLINK L 3740000` | `SBLINK <眼别> <起始时间>` | **眨眼开始** |
| `EBLINK L 3740000 3740150 150` | `EBLINK <眼别> <起始> <结束> <持续ms>` | **眨眼结束** |

---

## 八、完整文件结构一览

```
** ...                              <-- 文件头（注释）
DISPLAY_COORDS / RECCFG / ...       <-- 系统配置
START ...                           <-- 记录开始
PRESCALER / PUPIL / EVENTS / ...    <-- 格式声明
3733597  1218.7  592.1  8463.0 ...  <-- 每毫秒一行采样数据
SFIX L   3733604                    <-- EyeLink 自动检测：注视开始
EFIX L   3733604 3733867 264 ...    <-- 注视结束（含统计）
SSACC L  3733868                    <-- 眼跳开始
ESACC L  3733868 3733920 53 ...     <-- 眼跳结束（含幅度/速度）
SBLINK L 3740000                    <-- 眨眼开始
EBLINK L 3740000 3740150 150       <-- 眨眼结束
MSG  3741700 trig21                 <-- 实验 trigger（retro-cue）
END  6953128 ...                    <-- 记录结束
```
