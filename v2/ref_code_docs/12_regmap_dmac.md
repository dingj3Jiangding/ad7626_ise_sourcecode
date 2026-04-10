# 12 DMAC 寄存器文档解读

源文件：docs/regmap/adi_regmap_dmac.txt

## 1. 这个文档在驱动中的作用

它定义了 DMA 传输的编程接口，决定数据是否能正确写入内存。

## 2. 关键片段 1：DMA 使能与提交

```text
REG 0x100 CONTROL
[0] ENABLE

REG 0x102 TRANSFER_SUBMIT
[0] TRANSFER_SUBMIT
```

解释：

- ENABLE 打开通道。
- TRANSFER_SUBMIT 写 1 提交一次传输描述。

## 3. 关键片段 2：地址与长度

```text
REG 0x104 DEST_ADDRESS
REG 0x106 X_LENGTH  (bytes - 1)
```

解释：

- DEST_ADDRESS 要求按总线宽度对齐。
- X_LENGTH 是字节数减 1，这个细节最容易写错。

## 4. 关键片段 3：完成状态

```text
REG 0x101 TRANSFER_ID
REG 0x10a TRANSFER_DONE
```

解释：

- 提交后可读取 TRANSFER_ID，完成后到 TRANSFER_DONE 查对应 bit。
- 建议驱动保留 ID -> 缓冲区 的映射日志，便于排障。

## 5. 关键片段 4：模式控制

```text
REG 0x103 FLAGS
[0] CYCLIC
[1] TLAST
```

解释：

- 非循环采样一般保持 CYCLIC=0。
- TLAST 行为要和你的流接口语义一致。

## 6. 参考初始化顺序

1. 写 CONTROL.ENABLE=1
2. 写 DEST_ADDRESS
3. 写 X_LENGTH
4. 写 TRANSFER_SUBMIT=1
5. 轮询 TRANSFER_DONE 或等待中断

## 7. 常见错误

1. X_LENGTH 未减 1。
2. 目标地址未按总线对齐。
3. 没有先 ENABLE 就直接 SUBMIT。
4. 误把 TRANSFER_DONE 当成“单 bit 全局完成”。
