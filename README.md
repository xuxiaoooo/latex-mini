# LatexMini

一个小小的 macOS LaTeX 公式工具。

它做的事情很简单：

- 输入 LaTeX，自动实时预览
- 导出 SVG
- 复制 SVG
- 复制 MathML
- 支持窗口置顶

## 样子

- 轻
- 小
- 够用

## 构建

```bash
cd /Users/xuxiao/Code/latextool
./build.sh
```

构建后会得到：

- `build/LatexMini.app`
- `build/LatexMini.dmg`

## 依赖

- 本机可用的 `node`
- 本机可用的 `python3` + Pillow

不依赖 MacTeX。

## 目录

- `Sources/`
  SwiftUI 界面和窗口行为
- `Resources/Renderer/`
  LaTeX 到 SVG / MathML 的本地转换脚本
- `build.sh`
  打包 `.app`、`.dmg` 和图标
