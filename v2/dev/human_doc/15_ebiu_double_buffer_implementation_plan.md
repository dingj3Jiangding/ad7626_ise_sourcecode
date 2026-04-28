# EBIU + Double Buffer 实现计划

## 1. 背景

项目目前已经有一条可工作的 AD7626 采样链路，核心位于 `v2/dev/rtl/Day1-2`，重点是 source-synchronous 接收与板级 bring-up：

- `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
- `v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
- `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top_100m.v`

新的目标是在这条链路基础上继续扩展出稳定的数据导出路径：

```text
FPGA capture -> FPGA double buffer -> EBIU -> MDMA -> SDRAM -> USB
```

这一路径的约束条件和总体目标，已经记录在：

- `v2/dev/human_doc/14_blackfin_ebiu_double_buffer_plan.md`
- `v2/dev/human_doc/13_blackfin_fpga_interface_summary.md`

本文件关注的不是“原理为什么成立”，而是：

> 如何用最快且最稳的方式，把 EBIU + double buffer 功能一步步落到当前项目中。

核心原则是：**分阶段推进，每次只验证一个接口边界**。不要在 FPGA 双缓冲和 Blackfin EBIU/MDMA 还没分别验证清楚之前，就过早引入 USB 或完整软件链路。

---

## 2. 总体实现目标

目标是把当前稳定的 AD7626 采样结果：

- `sample_valid`
- `sample_data`

继续送入一个新的块级缓存与搬运链路中，使系统最终具备：

1. FPGA 侧持续接收 ADC 样点
2. FPGA 侧用双缓冲存储样点块
3. Blackfin 通过 EBIU 把 FPGA 当作 memory-mapped 外设访问
4. Blackfin 通过 MDMA 把完整数据块搬到 SDRAM/L1
5. USB 再从 SDRAM/L1 发送给上位机

---

## 3. 模块拆分建议

### 3.1 FPGA 侧

建议新增两个核心模块：

#### 1）`ad7626_double_buffer`
职责：
- 接收 `sample_valid/sample_data`
- 把样点写入当前活动 half-buffer
- 维护 `BUF0/BUF1` 的 ready/free 状态
- 维护当前 `active_buf`
- 维护 `half_word_count`
- 在双缓冲都不可写时置 `overrun`

#### 2）`ad7626_ebiu_regs_if`
职责：
- 解析 Blackfin 侧地址访问
- 实现 `REG_ID / REG_STATUS / REG_CTRL / REG_ACK / REG_HALF_WORD_COUNT`
- 暴露内部控制信号，例如：
  - `capture_enable`
  - `soft_reset`
  - `ack_buf0`
  - `ack_buf1`
- 向 Blackfin 返回状态信息和 buffer 窗口数据

### 3.2 顶层集成位置

建议把 Day2-1 作为双缓冲阶段目录，在以下顶层中集成新模块：

- `v2/dev/rtl/Day2-1/ad7626_day2_1_board_top.v`
- `v2/dev/rtl/Day2-1/ad7626_day2_1_board_top_100m.v`

其中：
- Day1-2 的 ADC 接收链保持不变，作为可信基线
- Day2-1 复用 `ad7626_s6_serial_capture` 等采样前端逻辑
- 新增 EBIU 相关顶层接口
- 下游新逻辑只消费 `sample_valid/sample_data`

### 3.3 Blackfin 侧

Blackfin 侧不负责采样，只负责：

1. 配置 EBIU Bank1 / AMS1
2. 读写 FPGA 寄存器
3. 轮询 buffer ready 状态
4. 发起 MDMA block copy
5. 在 MDMA 完成后写 ACK
6. 管理 SDRAM/L1 环形缓冲
7. 最后由 USB 从 SDRAM/L1 发数

---

## 4. 分阶段开发计划

## Stage 0 — 冻结当前采样基线

### 目标
把现有 Day1-2 采样链作为可信的数据生产端。

### 需要沿用并保持稳定的文件
- `v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v`
- `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v`
- `v2/dev/rtl/Day1-2/ad7626_day1_2_board_top_100m.v`
- `v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v`

### 要做的事
1. 把 `ad7626_day1_2_board_top.v` 输出的 `sample_valid + sample_data` 视为新缓冲逻辑唯一的上游接口。
2. 不要把 EBIU 总线逻辑混进 `ad7626_s6_serial_capture.v`。
3. 保持当前 capture path 独立，作为下游模块的稳定数据源。

### 成功标准
- 在加入任何下游集成前，现有 Day1-2 仿真仍能原样通过。

---

## Stage 1 — 先定义 FPGA 对外接口

### 目标
先冻结寄存器映射和总线可见行为，再开始写缓冲逻辑。

### 需要明确/实现
使用 `14_blackfin_ebiu_double_buffer_plan.md` 中定义的地址映射：

```text
0x2010_0000  REG_ID
0x2010_0002  REG_STATUS
0x2010_0004  REG_CTRL
0x2010_0006  REG_ACK
0x2010_0008  REG_HALF_WORD_COUNT
0x2010_1000  BUF0
0x2010_5000  BUF1
```

需要明确：
1. 每个寄存器的读写语义
2. 总线空闲时行为
3. 读/写周期下数据总线方向控制
4. 只支持 16-bit 对齐访问

### 成功标准
- 在仿真中，一个简化 bus master 可以稳定读写寄存器，并观察到确定性的状态变化。

---

## Stage 2 — 先实现 FPGA 双缓冲，不引入真实总线时序复杂度

### 目标
先证明缓冲所有权和切换逻辑正确，再去处理完整 EBIU 行为。

### 建议新增文件
- `v2/dev/rtl/Day2-1/ad7626_double_buffer.v`
- `v2/dev/tb/Day2-1/tb_ad7626_double_buffer.v`

### 实现行为
1. 每次 `sample_valid` 到来时，把 `sample_data` 写入当前活动缓冲。
2. 当前 half-buffer 达到配置深度时：
   - 置对应 `bufX_ready`
   - 若另一半空闲，则切换过去继续写
   - 否则置 `overrun`
3. 收到 `ack_buf0 / ack_buf1` 时：
   - 清 ready
   - 将对应缓冲重新标记为空闲
4. 维护：
   - `active_buf`
   - `half_word_count`
   - sticky `overrun`

### 初版建议简化
- half-buffer 深度固定，例如 4096 samples，但保留参数化
- 只支持单 ADC 通道
- 第一版不做 partial-buffer DMA

### 成功标准
- testbench 能证明 fill / switch / ack / overrun 行为正确
- 只有在软件刻意不 ACK 时才出现 overrun

---

## Stage 3 — 增加一个模拟 Blackfin 寄存器访问的仿真 bus master

### 目标
在动 Blackfin 固件之前，先从“软件可见视角”验证 FPGA 设计。

### 建议新增文件
- `v2/dev/tb/Day2-1/tb_ad7626_ebiu_path.v`

### testbench 需要模拟
1. 通过现有 Day1-2 生产链路，或简化生产器，生成样本流
2. 模拟 Blackfin 总线访问序列：
   - 写 `capture_enable`
   - 轮询 `REG_STATUS`
   - ready 后读取完整 buffer 窗口
   - 写 `REG_ACK`
3. 检查 buffer 内容是否连续、顺序是否正确

### 成功标准
- 在没有任何 Blackfin 固件的情况下，仅靠 testbench 就能验证完整 FPGA 侧软件接口契约

---

## Stage 4 — 将 FPGA 总线接口集成进 Day2-1 board top

### 目标
在尽量不打扰现有链路的前提下，把新功能暴露到顶层。

### 关键文件
- `v2/dev/rtl/Day2-1/ad7626_day2_1_board_top.v`
- `v2/dev/rtl/Day2-1/ad7626_day2_1_board_top_100m.v`
- 如新增顶层 pin，需要同步更新约束文件

### 具体改动
1. 保持当前 ADC 侧 pin 不变
2. 在顶层显式加入 EBIU 相关接口：
   - 地址总线
   - 16-bit 数据总线
   - `AMS1`
   - `ARE`
   - `AWE`
3. 在现有采样逻辑下方实例化：
   - `ad7626_double_buffer`
   - `ad7626_ebiu_regs_if`
4. 仅将 `sample_valid/sample_data` 接入 buffer manager

### 成功标准
- 原有采样调试输出依然可用
- 新增外部总线端口不会改变采样路径的基本结构

---

## Stage 5 — Blackfin 固件 bring-up：先只做寄存器访问

### 目标
先证明 EBIU 连通性，不要一开始就上 MDMA。

### Blackfin 侧需要做
1. 保守配置 EBIU Bank1 / AMS1 时序
2. 稳定读取 `REG_ID`
3. 写 `soft_reset`，再清掉
4. 写 `capture_enable`
5. 轮询 `REG_STATUS` 并记录状态变化
6. 手工写 `REG_ACK`，确认状态位确实更新

### 成功标准
- Blackfin 能稳定读写 FPGA 寄存器
- 软件侧能观察到：
  - `buf0_ready`
  - `buf1_ready`
  - `overrun`

---

## Stage 6 — Blackfin 固件 bring-up：只做 MDMA，不接 USB

### 目标
先独立验证块搬运，再谈上位机流式发送。

### Blackfin 侧需要做
1. 建一个固定大小的 SDRAM/L1 环形缓冲
2. 当 `buf0_ready` 置位时，执行：
   - `MDMA: BUF0 -> SDRAM`
   - 完成后 `ACK=1`
3. 当 `buf1_ready` 置位时，执行：
   - `MDMA: BUF1 -> SDRAM`
   - 完成后 `ACK=2`
4. 记录块计数、软件写指针和 overrun 事件
5. 通过内存 dump 或 checksum 验证搬运结果

### 关键规则
- ACK 必须发生在 MDMA 完成之后

### 成功标准
- 在预期服务窗口内，可持续把数据块稳定搬入 SDRAM，且没有 overrun
- 内存中的块数据顺序与样本顺序一致

---

## Stage 7 — 最后再加 USB，作为最终消费者

### 目标
让 USB 成为 SDRAM 的下游读取者，而不是实时采集服务环的一部分。

### Blackfin 侧需要做
1. 让 FPGA 服务逻辑与 USB 发送逻辑解耦
2. USB 只从 SDRAM 环形缓冲读数据
3. 增加 watermark / counter，用于观察 backlog

### 成功标准
- 即使 USB 短时间落后，也不会立刻导致 FPGA overrun
- 系统的第一故障模式应是 backlog 增长，而不是静默数据损坏

---

## 5. 推荐里程碑顺序

1. **Milestone A：先完成 FPGA 接口规格和寄存器语义定义**
   - 输出：冻结的寄存器映射和模块边界文档
2. **Milestone B：实现 FPGA 双缓冲模块 + 单元 testbench**
   - 输出：fill/switch/ack/overrun 已在仿真中证明
3. **Milestone C：实现 FPGA 总线/寄存器模块 + bus-master testbench**
   - 输出：软件可见契约已在仿真中证明
4. **Milestone D：集成到当前 board top**
   - 输出：新顶层加入 EBIU pin，旧采样路径保持不变
5. **Milestone E：Blackfin 先打通寄存器访问**
   - 输出：`REG_ID`、状态轮询、ACK 路径已在硬件上确认
6. **Milestone F：Blackfin 加入 MDMA 到 SDRAM**
   - 输出：不接 USB 时，块采集链路已稳定
7. **Milestone G：最后加 USB 流式输出**
   - 输出：端到端导出链路闭环完成

---

## 6. 初期应当延后的内容

为了尽快稳定落地，建议暂时延后：

- 多通道支持
- 动态 buffer 大小
- 中断驱动的 ready 通知
- partial-buffer 传输
- 高级吞吐优化
- 在基本功能未证明前就做激进时序调优
- SPI 辅助控制链路

---

## 7. 主要风险与控制方式

### 风险 1：过早把采样逻辑和总线逻辑搅在一起
解决：
- 严格保持采样链独立，只把它作为下游数据源

### 风险 2：还没证明逻辑行为就先做完整 EBIU 时序
解决：
- 先用仿真 bus master 验证逻辑，再上真实总线

### 风险 3：MDMA 完成前就提前 ACK
解决：
- ACK 只由软件在 MDMA 完成后发出

### 风险 4：USB 直接耦合进采集实时服务路径
解决：
- USB 只读 SDRAM 环形缓冲，不直接服务 FPGA

### 风险 5：可观测性不足，板上难调
解决：
- 尽早暴露 counters/status/debug 字段

---

## 8. 验证顺序

### 8.1 FPGA 仿真
- 重新运行现有 Day1-2 testbench，保护当前采样路径
- 为 `ad7626_double_buffer` 增加单元 testbench
- 增加总线级 testbench，模拟 Blackfin 轮询、整块读取和 ACK 写入
- 增加 overrun 压力测试：故意延迟 ACK

### 8.2 FPGA 硬件 bring-up
- 先从 Blackfin 侧验证寄存器可见性：
  - `REG_ID`
  - `REG_STATUS`
  - `REG_CTRL`
  - `REG_ACK`
- 在实时采样下确认 ready 位能按预期翻转
- 确认交替读取 `BUF0/BUF1` 时不存在数据损坏

### 8.3 Blackfin 软件验证
- 先做寄存器级 smoke test
- 再做 `BUF0/BUF1 -> SDRAM` 的 MDMA block-copy 测试，并检查 checksum / 内容
- 长时间运行测试：监控 overrun 计数和 SDRAM ring high-water mark
- 只有在 MDMA 路径稳定后，再做 USB 端到端测试
