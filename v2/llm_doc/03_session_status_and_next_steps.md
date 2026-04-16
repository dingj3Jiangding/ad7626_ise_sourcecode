# 当前会话进度与下一步

## 已完成事项

1. 目录策略已经固定：
   - `v2/ref` 作为参考代码区。
   - `v2/dev` 作为新开发区。
2. Day1 上午最小闭环已经完成：
   - `ad7626_min_timing_gen`
   - `ad7626_min_rx_core`
   - `ad7626_min_loopback_top`
   - `tb_ad7626_min_loopback`
3. Day1-2 板级 echoed-clock 最小实现已经落地：
   - `ad7626_day1_2_timing_gen`
   - `ad7626_s6_serial_capture`
   - `ad7626_day1_2_board_top`
   - `ad7626_day1_2_board_top_template.ucf`
   - `tb_ad7626_day1_2_board_top`
4. `v2/dev/human_doc` 已经更新到当前实现版，说明不再是旧的“两级同步占位方案”。
5. 已确认并写入当前默认 bring-up 取值：
   - `tCYC = 100 ns`
   - `tCNVH = 20 ns`
   - `tMSB = 100 ns`
   - `tCLK = 4 ns`
   - `READ_START = cycle(N+1) + 20 ns`
6. 已明确参数风险：
   - 之前把 `tMSB` 和 16 个 `CLK` 塞进同一个 `tCYC` 的理解是错误的。
   - 当前默认实现改成“下一拍固定读窗读上一拍结果”。

## 当前实现的真实边界

1. 当前 RTL 已经是 source-synchronous 接收，不是简单把 `D` 同步到系统时钟。
2. 顶层目前假设外部已经提供干净的 `sys_clk_250`。
3. `CNV` 当前按差分 LVDS 输出实现。
4. fake/hw 双模式保留，方便回退。
5. `board_top` 现在用 stage + pending queue 跟踪“conversion 启动”和“sample 真正返回”之间的一拍错位关系。

## 尚未完成事项

1. 补一个板级 `sys_clk_250` wrapper：
   - 如果板上晶振不是 250 MHz，需要 DCM/PLL 外壳。
2. 按实际原理图填写 `v2/dev/constraints/ad7626_day1_2_board_top_template.ucf` 的 `LOC`。
3. 在有 ISE 的机器上做综合/实现验证。
4. 根据后续板测结果补更严格的 source-synchronous 时序约束。
5. 视板卡实际情况确认 `CNV` 是否应改为单端 2.5 V CMOS。

## 推荐下一步执行顺序

1. 先确认板上系统时钟来源和频率。
2. 再确认 `CNV` 在你的板子上到底是差分还是单端。
3. 补 `UCF` 的实际引脚。
4. 在 ISE 14.7 下做一次综合。
5. 上板先看 `CNV`、`CLK`、`DCO`、`D`，再看 `sample_valid` 和 `sample_count`。

## 当前最重要的注意事项

1. 不要让下一个模型继续沿着旧文档去做“最小同步版输入”。
2. 不要假设仓库里已经有 `v2/dev/sim/Makefile` 或完整 ISim 启动脚本。
3. 不要把 `v2/dev/human_doc` 误写成 `v2/dev/doc`。
