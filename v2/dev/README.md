# v2/dev Day1 最小数字闭环

本目录用于放置新开发代码。
`v2/ref` 仅作为参考，不在其中做功能开发改动。

## Day1 上午目标

实现并验证最小闭环：

1. 时序发生（frame_start + bit_tick）。
2. 串行移位接收并组帧。
3. 输出 sample_valid / sample_data / sample_count。
4. 帧对齐错误检测与数据一致性检测。

## 文件说明

- `rtl/ad7626_min_timing_gen.v`
  生成帧起始与位采样节拍。
- `rtl/ad7626_min_rx_core.v`
  执行串行移位接收、样本有效脉冲与样本计数。
- `rtl/ad7626_min_loopback_top.v`
  内置递增测试模式串行源，回环到接收核，便于纯数字快速验证。
- `tb/tb_ad7626_min_loopback.v`
  自检 testbench，出现对齐或数据错误会直接失败。
- `sim/Makefile`
  一键编译运行仿真（iverilog + vvp）。

## 运行方法

在仓库根目录执行：

```bash
cd v2/dev/sim
make run
```

说明：

- `make run` 默认走 ISE 14.7 的 ISim 流程（`fuse` + `-tclbatch`）。
- 如果你临时在非 ISE 环境做快速语法验证，可用 `make iverilog_run`。

期望输出包含：

```text
[TB][PASS] Reached 128 samples without align/data errors.
```

## 下一步（Day1 下午）

1. 把 `ad7626_min_loopback_top.v` 内部测试串行源替换为板级 `dco/data` 输入。
2. 保留 `sample_valid/sample_count/align_error` 调试信号，先上 ILA 观察稳定性。
3. 在硬件稳定后，再接最小寄存器映射与 DMA。
