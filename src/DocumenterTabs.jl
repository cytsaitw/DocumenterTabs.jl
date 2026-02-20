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

# ---------------------------------------------------------------------------
# Public Plugin type
# ---------------------------------------------------------------------------

"""
    DocumenterTabsPlugin()

Instantiate and pass to the `plugins` keyword of `Documenter.makedocs` to
enable the `!!! tabs` syntax.
"""
struct DocumenterTabsPlugin <: Documenter.Plugin end

# ---------------------------------------------------------------------------
# Custom MarkdownAST elements
# ---------------------------------------------------------------------------

"""
    TabsBlock(labels)

A custom Documenter block element that replaces a `!!! tabs` admonition node.
The tab labels are stored here; the panel content nodes live as ordinary
children of the same `Node` in the AST.

Panel children are wrapped in `TabPanelNode` elements so that `domify` can
identify panel boundaries.
"""
struct TabsBlock <: Documenter.AbstractDocumenterBlock
    labels::Vector{String}
end

"""Wrapper element that holds all nodes belonging to one tab panel."""
struct TabPanelBlock <: Documenter.AbstractDocumenterBlock
    index::Int   # 0-based tab index
end

"""
Inline `<style>` + `<script>` asset block appended to every page.
We store the full asset text here so the build is hermetic (no file copying).
"""
struct TabsAssetBlock <: Documenter.AbstractDocumenterBlock
    css::String
    js::String
end

# MarkdownAST container declarations — must come after all types are defined
# TabsBlock: container that only holds TabPanelBlock children
MarkdownAST.iscontainer(::TabsBlock) = true
MarkdownAST.can_contain(::TabsBlock, ::MarkdownAST.AbstractElement) = false
MarkdownAST.can_contain(::TabsBlock, ::TabPanelBlock) = true

# TabPanelBlock: container that can hold any block element
MarkdownAST.iscontainer(::TabPanelBlock) = true
MarkdownAST.can_contain(::TabPanelBlock, child::MarkdownAST.AbstractElement) =
    isa(child, MarkdownAST.AbstractBlock)

# ---------------------------------------------------------------------------
# Helpers: extract plain text from a heading node
# ---------------------------------------------------------------------------

function _heading_text(heading_node::Node)
    buf = IOBuffer()
    _flatten!(buf, heading_node)
    strip(String(take!(buf)))
end

function _flatten!(io::IO, node::Node)
    el = node.element
    if el isa MarkdownAST.Text
        print(io, el.text)
    elseif el isa MarkdownAST.Code
        print(io, el.code)
    elseif el isa MarkdownAST.SoftBreak || el isa MarkdownAST.LineBreak
        print(io, " ")
    else
        for child in node.children
            _flatten!(io, child)
        end
    end
end

# ---------------------------------------------------------------------------
# Core transformation: !!! tabs admonition → TabsBlock AST node
# ---------------------------------------------------------------------------

"""
Replace a `!!! tabs` admonition `node` with a `TabsBlock` node whose children
are the panel content nodes wrapped in `TabPanelBlock` elements.
"""
function _transform_tabs_node!(node::Node)
    # Snapshot children before we modify anything
    children = collect(node.children)

    labels = String[]
    panels = Vector{Vector{Node}}()
    current = Vector{Node}()

    for child in children
        if child.element isa MarkdownAST.Heading
            # Starting a new tab — save the previous panel (if any)
            if !isempty(labels)
                push!(panels, current)
                current = Vector{Node}()
            end
            push!(labels, _heading_text(child))
        else
            push!(current, child)
        end
    end
    # Flush last panel
    push!(panels, current)

    # Build the replacement node
    tabs_node_element = TabsBlock(labels)
    node.element = tabs_node_element

    # Detach every existing child from the node first
    for child in collect(node.children)
        MarkdownAST.unlink!(child)
    end

    # Re-attach panel content wrapped in TabPanelBlock nodes
    for (i, panel_children) in enumerate(panels)
        panel_node = Node(TabPanelBlock(i - 1))   # 0-based index
        for child in panel_children
            MarkdownAST.unlink!(child)             # detach from old parent
            push!(panel_node.children, child)
        end
        push!(node.children, panel_node)
    end
end

# ---------------------------------------------------------------------------
# Builder pipeline stage 1: transform all !!! tabs admonitions (runs early)
# ---------------------------------------------------------------------------

abstract type TabsTransformer <: Documenter.Builder.DocumentPipeline end
Selectors.order(::Type{TabsTransformer}) = 1.5   # before ExpandTemplates (5.0)

function Selectors.runner(::Type{TabsTransformer}, doc::Documenter.Document)
    for page in values(doc.blueprint.pages)
        _transform_page!(page.mdast)
    end
end

function _transform_page!(root::Node)
    for node in collect(AbstractTrees.PreOrderDFS(root))
        el = node.element
        if el isa MarkdownAST.Admonition && el.category == "tabs"
            _transform_tabs_node!(node)
        end
    end
end

# ---------------------------------------------------------------------------
# Builder pipeline stage 2: inject inline CSS + JS into every page
# ---------------------------------------------------------------------------

abstract type TabsAssetInjector <: Documenter.Builder.DocumentPipeline end
Selectors.order(::Type{TabsAssetInjector}) = 1.6  # just after transformation

const _CSS_PATH = joinpath(@__DIR__, "assets", "tabs.css")
const _JS_PATH = joinpath(@__DIR__, "assets", "tabs.js")

function Selectors.runner(::Type{TabsAssetInjector}, doc::Documenter.Document)
    # Skip if the plugin was not registered by the user
    Documenter.getplugin(doc, DocumenterTabsPlugin) === nothing && return

    css = isfile(_CSS_PATH) ? read(_CSS_PATH, String) : ""
    js = isfile(_JS_PATH) ? read(_JS_PATH, String) : ""

    asset_element = TabsAssetBlock(css, js)
    for page in values(doc.blueprint.pages)
        push!(page.mdast.children, Node(asset_element))
    end
end

# ---------------------------------------------------------------------------
# HTMLWriter integration: domify
# ---------------------------------------------------------------------------

function Documenter.HTMLWriter.domify(dctx::DCtx, node::Node, el::TabsBlock)
    DOM.@tags div button

    # Build a stable group key from the *sorted* label set so that all
    # tab groups sharing the same labels sync together via localStorage.
    group_key = join(sort(el.labels), "|")

    # Render label buttons
    label_btns = [
        button[
            ".doc-tabs__label",
            Symbol("data-tab")=>string(i - 1),
            Symbol("data-tabs-group")=>group_key,
        ](label)
        for (i, label) in enumerate(el.labels)
    ]

    # Render panels by dispatching on each TabPanelBlock child
    panel_divs = map(collect(node.children)) do panel_node
        Documenter.HTMLWriter.domify(dctx, panel_node, panel_node.element)
    end

    div[
        ".doc-tabs",
        Symbol("data-tabs-group")=>group_key,
    ](
        div[".doc-tabs__labels"](label_btns...),
        panel_divs...
    )
end

function Documenter.HTMLWriter.domify(dctx::DCtx, node::Node, el::TabPanelBlock)
    DOM.@tags div
    # Recursively domify the panel's children (code blocks, paragraphs, etc.)
    inner = Documenter.HTMLWriter.domify(dctx, node.children)
    div[
        ".doc-tabs__panel",
        Symbol("data-tab")=>string(el.index),
    ](inner...)
end

function Documenter.HTMLWriter.domify(::DCtx, ::Node, el::TabsAssetBlock)
    DOM.@tags style script
    # Emit inline <style> and <script> once per page
    [style(el.css), script(el.js)]
end

# ---------------------------------------------------------------------------
# MDFlatten — keep search indexing safe (silently skip tab content)
# ---------------------------------------------------------------------------
# Documenter already has a fallback for AbstractDocumenterBlock that errors;
# we override it for our types to be a no-op so the search index build works.
Documenter.MDFlatten.mdflatten(io, ::Node, ::TabsBlock) = nothing
Documenter.MDFlatten.mdflatten(io, ::Node, ::TabPanelBlock) = nothing
Documenter.MDFlatten.mdflatten(io, ::Node, ::TabsAssetBlock) = nothing

end # module DocumenterTabs
