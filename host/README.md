# eidolon-host — Eidolon 组合根

**Host 是 Eidolon 第一个真正意义上的生态边界。**

- **Kernel** 定义计算模型(NodeType/Graph/Event/State/Execution/AssetRef/Capability 边界)
- **DSL** 定义节点语言
- **Host** 定义如何把外部世界装配进这个计算模型

本目录是组合根所在;根目录 `editor/` 与 `runtime/` 下的兄弟项目(独立 git 仓库)
与 Kernel、DSL 等平级分类,逻辑上以 git 源 + pin rev 的包依赖方式被宿主引用,
可独立演化和发布。

```text
                 Host
        ┌──────────┼──────────┐
        ↓          ↓          ↓
     Editor     Runtime    Project
        │          │
        └────┬─────┘
             ↓
      Common Host Services
       ├── Plugins
       ├── Assets
       ├── DSL
       └── Registry
             ↓
          Kernel
```

当前状态:位置调整完成,宿主代码尚未实现(阶段目标 = 内核稳定)。
