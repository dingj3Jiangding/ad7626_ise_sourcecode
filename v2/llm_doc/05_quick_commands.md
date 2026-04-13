# 快速命令参考

以下命令在仓库根目录执行：

## 1) 查看 `v2/dev` 当前文件布局

```bash
find ad7626_ise_sourcecode/v2/dev -maxdepth 3 -type f | sort
```

## 2) 快速看 Day1-2 关键 RTL

```bash
sed -n '1,260p' ad7626_ise_sourcecode/v2/dev/rtl/Day1-2/ad7626_day1_2_timing_gen.v
sed -n '1,320p' ad7626_ise_sourcecode/v2/dev/rtl/Day1-2/ad7626_s6_serial_capture.v
sed -n '1,360p' ad7626_ise_sourcecode/v2/dev/rtl/Day1-2/ad7626_day1_2_board_top.v
sed -n '1,420p' ad7626_ise_sourcecode/v2/dev/tb/Day1-2/tb_ad7626_day1_2_board_top.v
```

## 3) 快速看 human_doc 入口

```bash
sed -n '1,220p' ad7626_ise_sourcecode/v2/dev/human_doc/00_INDEX.md
```

## 4) 快速看 llm_doc 入口

```bash
sed -n '1,220p' ad7626_ise_sourcecode/v2/llm_doc/00_INDEX.md
```

## 5) 搜索旧口径是否还残留

```bash
rg -n "v2/dev/sim|v2/dev/doc|两级同步|最小同步|200 ns" ad7626_ise_sourcecode/v2
```

## 6) 在有 ISE 的机器上至少先确认工具是否存在

```bash
which xst
which fuse
```

## 7) 快速检查约束模板

```bash
sed -n '1,220p' ad7626_ise_sourcecode/v2/dev/constraints/ad7626_day1_2_board_top_template.ucf
```
