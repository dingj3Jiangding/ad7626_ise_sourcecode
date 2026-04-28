# Blackfin CPU 与 FPGA 通信接口总结

## 1. 结论

从当前这张 Blackfin CPU 与 FPGA 的接口图来看，两者之间可以明确识别出的通信方式主要包括：

1. 并行异步总线通信
2. SPI 串行通信
3. 时钟/同步信号交互
4. GPIO 控制与状态信号交互

其中，主通信方式是并行异步总线；SPI 更像辅助控制或低速配置通道；其余信号主要用于同步、复位、上电控制和状态反馈。

## 2. 并行异步总线通信

图中可以直接看到一组地址总线、数据总线和读写控制线：

- 地址线：`A[1:19]`
- 数据线：`D[0:15]`
- 控制线：`ASYNC_AMS1`、`AWE`、`ARE`

这组信号非常像 Blackfin 的异步外部总线/外部存储器接口，意味着 CPU 可以将 FPGA 映射成一个 memory-mapped 外设，通过地址和读写控制直接访问 FPGA 内部寄存器或缓冲区。

### 2.1 信号含义

- `A[1:19]`：地址选择信号，通常由 CPU 输出到 FPGA
- `D[0:15]`：16 位数据总线，通常为双向
- `ASYNC_AMS1`：异步存储器片选/Bank 选择
- `AWE`：写使能
- `ARE`：读使能

### 2.2 典型访问方式

- CPU 写 FPGA：CPU 给出地址，拉动片选和 `AWE`，将数据写入 FPGA
- CPU 读 FPGA：CPU 给出地址，拉动片选和 `ARE`，由 FPGA 驱动数据总线返回数据

### 2.3 方向判断

- `CPU -> FPGA`：`A[1:19]`、`ASYNC_AMS1`、`AWE`、`ARE`
- `CPU <-> FPGA`：`D[0:15]`

## 3. SPI 串行通信

图中还能识别出一组明显的 SPI 复用信号：

- `PG2/SCK_SW`：SPI 时钟 `SCK`
- `PG4/MOSI/DTOSECA_SW`：主发从收 `MOSI`
- `PG3/MISO/DROSECA_SW`：主收从发 `MISO`
- `PH9/SPISEL5/...` 或 `PF10/.../SPISEL7`：SPI 片选 `CS`

这说明 CPU 与 FPGA 之间还预留或使用了一组 SPI 风格的串行通信接口，通常可用于：

- 配置寄存器访问
- 状态读取
- 低速控制命令传输

### 3.1 方向判断

- `CPU -> FPGA`：`SCK`、`MOSI`、`CS`
- `FPGA -> CPU`：`MISO`

## 4. 时钟与同步信号

图中可以看到多条与时钟、同步相关的信号：

- `CLKOUT_BUF`
- `FMC_PG_C2M`
- `SYSTEM_CLK`
- `PS_350KHZ_SYNC_CLK`
- `PS_1050KHZ_SYNC_CLK`
- `PH13/ERXCLK`

这些信号表明两者之间不仅有数据交互，还有时钟参考或同步配合，用于：

- 给对端提供时钟参考
- 保证采样/处理时序一致
- 支持固定频率的同步触发

仅根据当前这一页原理图，无法完全确定每根时钟线的源端和最终用途，但可以确认 FPGA 与 CPU 之间存在专门的时钟/同步交互。

## 5. GPIO 控制与状态信号

图中还有一些明显不属于主数据通道的控制/状态线：

- `SW_GPIO_RESET`
- `FMC_PRSNT_M2C_L`
- `FMC_POWER_EN`
- `FPGA_LED0`
- `FPGA_LED1`
- `FPGA_LED2`

这些信号通常用于：

- 复位控制
- 板卡在位检测
- 电源使能
- 调试状态指示

### 5.1 典型作用

- `SW_GPIO_RESET`：CPU 或控制逻辑对 FPGA/外设进行复位
- `FMC_POWER_EN`：电源使能控制
- `FMC_PRSNT_M2C_L`：在位/存在检测
- `FPGA_LED[0:2]`：运行状态或调试状态输出

## 6. 不能仅凭本页确定的部分

图中某些引脚名称带有多个复用功能，例如：

- `PG13/UART1RXA/TACI2`
- `PF10/PPI_D10/RFS1/SPISEL7`
- `PH9/SPISEL5/ETXD2/TACLK3`

这类写法说明 Blackfin 引脚支持多功能复用，但不能仅凭这一页就断定 UART、PPI 或其他复用外设一定已经实际使用。

因此，基于当前图纸，能够较有把握确认的是：

- 存在并行异步总线接口
- 存在 SPI 串行接口
- 存在时钟/同步相关连线
- 存在 GPIO 类控制/状态连线

而 UART、PPI 等功能是否真正参与 FPGA 与 CPU 通信，还需要结合更多页原理图或软件/FPGA 代码继续确认。

## 7. 总结表

| 通信/交互类型 | 相关信号 | 结论 |
| --- | --- | --- |
| 并行异步总线 | `A[1:19]`、`D[0:15]`、`ASYNC_AMS1`、`AWE`、`ARE` | 明确存在，且应为主通信方式 |
| SPI 串行接口 | `SCK`、`MOSI`、`MISO`、`SPISELx` | 明确存在，适合辅助控制/配置 |
| 时钟/同步 | `CLKOUT_BUF`、`SYSTEM_CLK`、`PS_*_SYNC_CLK`、`ERXCLK` | 明确存在，用于同步或时钟参考 |
| GPIO/控制状态 | `SW_GPIO_RESET`、`FMC_POWER_EN`、`FMC_PRSNT_M2C_L`、`FPGA_LED[0:2]` | 明确存在，用于复位、上电、状态反馈 |

## 8. 一句话结论

从该接口图可看出，Blackfin CPU 与 FPGA 之间的主要通信方式是 16 位数据总线配合地址/读写控制构成的并行异步总线，同时辅以 SPI 串行链路，以及若干时钟同步线和 GPIO 控制状态线。
