# 10 up_axi.v 详解

源文件：library/common/up_axi.v

## 1. 这个文件的角色

这是 AXI-Lite 到 ADI 内部寄存器总线的桥接器，完成：

1. AXI 写握手 -> up_wreq/up_waddr/up_wdata
2. AXI 读握手 -> up_rreq/up_raddr/up_rdata
3. 超时与默认返回处理

## 2. 关键片段 1：地址转换

```verilog
output  [(AXI_ADDRESS_WIDTH-3):0] up_waddr,
output  [(AXI_ADDRESS_WIDTH-3):0] up_raddr,

up_waddr_int <= up_axi_awaddr[(AXI_ADDRESS_WIDTH-1):2];
up_raddr_int <= up_axi_araddr[(AXI_ADDRESS_WIDTH-1):2];
```

解释：

- 内部地址按 32-bit 字寻址。
- 这意味着驱动里若使用 byte 地址，需要做 reg_offset << 2。

## 3. 关键片段 2：写通道状态机

```verilog
up_wsel <= up_axi_awvalid & up_axi_wvalid;
up_wreq_int <= up_axi_awvalid & up_axi_wvalid;

if (up_wack_s == 1'b1) begin
  up_wcount <= 5'h00;
end else if (up_wreq_int == 1'b1) begin
  up_wcount <= 5'h10;
end
```

解释：

- 只在地址和数据同拍有效时发起一次内部写请求。
- up_wcount 是等待应答计数，带超时保护。

## 4. 关键片段 3：读通道状态机

```verilog
up_rsel <= up_axi_arvalid;
up_rreq_int <= up_axi_arvalid;

assign up_rack_s = (up_rcount == 5'h1f) ? 1'b1 : (up_rcount[4] & up_rack);
assign up_rdata_s = (up_rcount == 5'h1f) ? {2{16'hdead}} : up_rdata;
```

解释：

- 若内部无应答，超时后返回 0xDEADDEAD。
- 这是定位总线映射错误的实用特征。

## 5. 迁移对你有什么价值

1. 明确寄存器地址单位，避免驱动偏移写错。
2. 明确握手机制，便于你实现非 AXI 的兼容桥。
3. 明确超时行为，便于调试早期硬件未连通场景。

## 6. 新板驱动建议

1. 统一封装读写 API：reg_write(reg_word, val)、reg_read(reg_word)。
2. 若底层总线改造，保持“字地址语义”不变。
3. 出现 0xDEADDEAD 时优先排查地址映射和时钟复位。
