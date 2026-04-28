# Blackfin EBIU 双缓冲采集方案

## 1. 目标

在当前硬件连接条件下，采用 `FPGA 双缓冲 -> Blackfin EBIU(AMS1) -> MDMA -> SDRAM/L1 -> USB OTG -> 上位机` 的数据通路，实现 ADC 连续采样数据的稳定搬运，避免 CPU 逐点轮询导致的丢样风险。

当前已确认条件：

- ADC 当前配置为 `1` 通道
- 每 `100 ns` 产生 `1` 个 `16-bit` 样点
- 当前持续数据率为 `10 MSPS x 16 bit = 20 MB/s`
- Blackfin 与 FPGA 之间已连接 `A[1:19]`、`D[0:15]`、`ASYNC_AMS1`、`ARE`、`AWE`
- 当前未见 `AOE`、`ARDY`、`ABE[1:0]`、`DMAR0/1`

结论：

- 不采用 `HMDMA/FIFO` 握手方案
- 不采用 CPU 逐点轮询寄存器方案
- 采用 `EBIU 异步 Bank1 + FPGA 双缓冲 + 普通 MDMA` 方案

## 2. 方案依据

依据 `ADSP-BF52x Hardware Reference`：

- `EBIU` 支持异步设备，包括 `FIFOs` 和 `ASIC/FPGA designs`
- 异步外设可作为 `memory-mapped I/O`
- `AMS1` 对应异步 Bank1，地址窗口为 `0x2010_0000 ~ 0x201F_FFFF`
- EBIU 支持来自 `core` 和 `DMA` 的访问
- 凡是 EBIU 支持的外部设备，也可被普通 `MDMA` 访问

因此，FPGA 可被设计为挂在 `AMS1` 上的存储器映射外设，由 Blackfin 通过 EBIU 读写寄存器和缓冲区，再通过 MDMA 做整块搬运。

## 3. 总体架构

### 3.1 数据路径

```text
ADC -> FPGA采样接收逻辑 -> FPGA双缓冲(BUF0/BUF1)
    -> EBIU AMS1映射
    -> Blackfin MDMA搬运到SDRAM/L1
    -> USB OTG发送到上位机
```

### 3.2 设计原则

- FPGA 对 Blackfin 呈现为 `16-bit` 异步存储器映射设备
- CPU 不读取单个样点，只处理“哪一块缓冲区已满”
- FPGA 负责样点写入缓冲区和缓冲切换
- Blackfin 负责块级搬运和上位机发送
- USB 发送只从内存缓冲区取数，不直接访问 FPGA

## 4. EBIU 访问模型

### 4.1 Bank 选择

- 使用 `AMS1`
- 基地址固定为 `0x2010_0000`

### 4.2 总线使用约束

- 按 `16-bit` 设备建模
- 软件仅做 `16-bit` 对齐访问
- 不依赖字节使能
- 不依赖外部 ready 握手
- EBIU 时序采用固定 wait state，先保守配置 `setup/access/hold`

### 4.3 推荐地址布局

```text
0x2010_0000  REG_ID
0x2010_0002  REG_STATUS
0x2010_0004  REG_CTRL
0x2010_0006  REG_ACK
0x2010_0008  REG_HALF_WORD_COUNT
0x2010_1000  BUF0
0x2010_5000  BUF1
```

说明：

- 所有寄存器均按 `16-bit` 宽度定义
- `REG_HALF_WORD_COUNT` 表示每半缓冲当前有效 `16-bit` 样点数
- `BUF0`、`BUF1` 间隔预留足够地址空间，避免后续扩展时重排地址

## 5. FPGA 侧设计

### 5.1 双缓冲组织

FPGA 内部维护两个采样缓冲区：

- `BUF0`
- `BUF1`

任一时刻：

- 一个缓冲区用于接收 ADC 新样点
- 另一个缓冲区等待被 Blackfin 读取或已被释放

### 5.2 最小状态寄存器定义

`REG_STATUS` 建议位定义：

- `bit0`: `buf0_ready`
- `bit1`: `buf1_ready`
- `bit2`: `active_buf`
- `bit3`: `overrun`

`REG_CTRL` 建议至少支持：

- `bit0`: `capture_enable`
- `bit1`: `soft_reset`

`REG_ACK` 建议语义：

- 写 `1`：释放 `BUF0`
- 写 `2`：释放 `BUF1`

### 5.3 缓冲切换逻辑

1. FPGA 将 ADC 样点持续写入当前活动缓冲区
2. 当前缓冲区写满后，置对应 `bufX_ready`
3. 若另一缓冲区空闲，则切换到另一缓冲区继续采样
4. 若另一缓冲区仍未被 CPU 释放，则置 `overrun`
5. CPU/MDMA 处理完后，通过 `REG_ACK` 释放对应缓冲区

### 5.4 缓冲区容量建议

当前数据率为 `20 MB/s`，建议每半缓冲至少：

- 最低配置：`4096` samples = `8 KB`，覆盖约 `409.6 us`
- 推荐配置：`8192` samples = `16 KB`，覆盖约 `819.2 us`

若 FPGA 资源允许，优先采用 `8192 samples/half`。

## 6. Blackfin 侧软件流程

### 6.1 初始化阶段

1. 配置 EBIU `Bank1`
2. 使能 `AMS1` 对应异步 bank
3. 设置固定时序参数
4. 读取 `REG_ID` 验证接口连通
5. 配置 MDMA 源/目的地址与块大小
6. 初始化 SDRAM/L1 环形缓冲
7. 使能 USB OTG 发送路径

### 6.2 运行阶段

1. 轮询 `REG_STATUS`
2. 若 `buf0_ready=1`，启动一次 `MDMA: BUF0 -> SDRAM`
3. MDMA 完成后，写 `REG_ACK=1`
4. 若 `buf1_ready=1`，启动一次 `MDMA: BUF1 -> SDRAM`
5. MDMA 完成后，写 `REG_ACK=2`
6. USB 发送任务从 SDRAM 环形缓冲异步取数并发送到上位机

注意：

- 这里允许“块级轮询”
- 不允许“样点级轮询”
- CPU 不应在采样主循环中逐点读取 `BUF0/BUF1`

## 7. MDMA 搬运策略

### 7.1 源与目的

- 源地址：`0x2010_1000` 或 `0x2010_5000`
- 目的地址：SDRAM 或 L1 中的软件环形缓冲

### 7.2 传输粒度

- 传输单位按 `16-bit` 样点组织
- 每次搬运一整个 half-buffer
- 完成一次搬运后再释放对应 FPGA 缓冲区

### 7.3 软件建议

- 使用固定块大小，避免运行时频繁重算参数
- 搬运完成后再更新上层发送指针
- USB 发送和 MDMA 搬运解耦，避免直接耦合 FPGA 口与 USB 中断节奏

## 8. 为什么不采用 CPU 逐点轮询

对当前 `10 MSPS`、`16-bit`、连续不丢样目标，CPU 逐点轮询不合适，原因如下：

- FPGA 若只暴露“当前值寄存器”，每 `100 ns` 新数据会覆盖旧数据
- CPU 必须在最坏情况下每 `100 ns` 内完成一次外部访问，实时性要求过高
- EBIU 异步读本身存在时序等待，不是单条指令即可零等待取回
- CPU 还需承担缓冲管理、MDMA 调度、USB 发送与中断处理
- 块缓冲把“100 ns 服务一次”转换成“数百 us 服务一次”，大幅降低调度压力

## 9. 验证计划

### 9.1 硬件连通性验证

- EBIU 能稳定读回 `REG_ID`
- CPU 能写 `REG_CTRL`
- CPU 能清除 `REG_ACK`
- FPGA 状态位能正确翻转

### 9.2 缓冲机制验证

- `BUF0` 满后 `buf0_ready` 置位
- `BUF1` 满后 `buf1_ready` 置位
- `ACK` 后对应缓冲区重新进入可写状态
- 在正常服务节奏下 `overrun=0`

### 9.3 数据正确性验证

- FPGA 缓冲中的样点顺序与 ADC 实际顺序一致
- MDMA 搬运后，SDRAM 数据无乱序、无重复、无缺点
- USB 发送到上位机后，样点数与缓冲计数一致

### 9.4 压力验证

- 在持续 `20 MB/s` 下长时间运行
- 检查 `overrun` 是否出现
- 检查 USB 发送端是否积压
- 统计软件环形缓冲高水位

## 10. 后续扩展判断

当前 `1` 通道配置的数据率为：

```text
1 x 10 MSPS x 16 bit = 20 MB/s
```

未来若扩到 `8` 通道且保持同规格：

```text
8 x 10 MSPS x 16 bit = 160 MB/s
```

因此：

- 本方案适合作为当前 `1` 通道版本的落地方案
- 若未来扩到多通道高带宽，需重新评估 USB OTG、SDRAM 带宽、CPU 调度以及整体链路架构
- 多通道版本可能需要更大 FPGA 缓冲、更多块并行、甚至更换上位机传输链路

## 11. 当前定版结论

当前推荐定版方案如下：

```text
FPGA双缓冲(BUF0/BUF1)
-> AMS1映射到0x2010_0000空间
-> Blackfin块级轮询状态
-> MDMA整块搬运到SDRAM
-> USB OTG异步发送到上位机
```

这是在当前已知硬件连接条件下，最稳妥、最容易验证、且不依赖缺失握手信号的实现方案。
