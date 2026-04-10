# 快速命令参考

以下命令在仓库根目录执行：

## 1) 查看当前分支与改动

```bash
git rev-parse --is-inside-work-tree && git status --short --branch
```

## 2) 查看 v2 目录结构（3 层）

```bash
find v2 -maxdepth 3 -type d | sort
```

## 3) 查看 dev 与 ref 的顶层内容

```bash
find v2/dev -maxdepth 2 -type d | sort
find v2/ref -maxdepth 2 -type d | sort
```

## 4) ISE 仿真入口（在有 ISE 的机器上）

```bash
cd v2/dev/sim
make clean
make run
```

## 5) 文档入口

```bash
cat v2/llm_doc/00_INDEX.md
cat v2/dev/doc/00_INDEX.md
```
