# v2 LLM 交接文档索引

本目录用于在对话上下文不足或切换模型时，快速恢复项目背景与开发约束。

## 文件列表

1. `01_project_constraints.md`
   项目边界、目录规则、工具链约束。
2. `02_code_style_and_conventions.md`
   代码风格、文档风格、仿真兼容性要求。
3. `03_session_status_and_next_steps.md`
   当前完成情况、未完成项、下一步建议。
4. `04_prompt_for_next_llm.md`
   可直接复制给下一个大模型的启动提示词。
5. `05_quick_commands.md`
   常用检查命令与最小验证命令。
6. `AD7626_echoed_clock_interface_guide.md`
   基于 AD7626 datasheet 的 echoed-clock 模式接口与时序摘要。

## 30 秒恢复上下文

1. 本项目当前主开发区域是 `v2/dev`。
2. `v2/ref` 是原版参考代码，只读参考，不在其中做新开发。
3. 目标平台是 Spartan-6，工具链是 ISE 14.7。
4. Day1 上午最小闭环代码已在 `v2/dev/rtl`、`v2/dev/tb`、`v2/dev/sim`。
5. 模块讲解文档在 `v2/dev/doc`，已改成“代码片段 + 解释”风格。
6. AD7626 echoed-clock 关键时序和 LVDS 规则在 `v2/llm_doc/AD7626_echoed_clock_interface_guide.md`。
