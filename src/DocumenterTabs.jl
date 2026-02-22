"""
    DocumenterTabs

A Documenter.jl plugin that converts `!!! tabs` admonitions into interactive
tab-panel UI components.

## Quick Start

In your `docs/make.jl`:

```julia
using Documenter, DocumenterTabs

makedocs(
    plugins = [DocumenterTabs.DocumenterTabsPlugin()],
    ...
)
```

Then in any Markdown page:

```markdown
!!! tabs
    ## Julia
    ```julia
    println("Hello from Julia!")
    ```

    ## Python
    ```python
    print("Hello from Python!")
    ```
```

### Tab Syncing

Tabs with the same label set (e.g. every `["Julia", "Python"]` group on the
site) are automatically synced via `localStorage`.  If a user picks "Python"
on one page, every other tab group with the same labels will also switch to
"Python".
"""
module DocumenterTabs

using MarkdownAST: MarkdownAST, Node
using Documenter: Documenter, Selectors, DOM
using Documenter.HTMLWriter: DCtx
import AbstractTrees

include("elements.jl")   # TabsBlock, TabPanelBlock, TabsAssetBlock + can_contain
include("transform.jl")  # _heading_text, _flatten!, _transform_tabs_node!, _transform_page!
include("pipeline.jl")   # TabsTransformer, TabsAssetInjector pipeline stages
include("render.jl")     # domify() + mdflatten() implementations

end # module DocumenterTabs
