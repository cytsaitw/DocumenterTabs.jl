# elements.jl — Custom MarkdownAST element types for DocumenterTabs.jl
#
# Defines the three AST block types used by this plugin, together with their
# MarkdownAST container / can_contain declarations so that the tree mutation
# in transform.jl is accepted by MarkdownAST's validation layer.

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
# Element types
# ---------------------------------------------------------------------------

"""
    TabsBlock(labels)

A custom Documenter block element that replaces a `!!! tabs` admonition node.
The tab labels are stored here; the panel content nodes live as ordinary
children of the same `Node` in the AST, each wrapped in a `TabPanelBlock`.
"""
struct TabsBlock <: Documenter.AbstractDocumenterBlock
    labels::Vector{String}
end

"""
    TabPanelBlock(index)

Wrapper element that holds all block nodes belonging to one tab panel.
`index` is 0-based and matches the corresponding label in the parent
`TabsBlock`.
"""
struct TabPanelBlock <: Documenter.AbstractDocumenterBlock
    index::Int   # 0-based tab index
end

"""
    TabsAssetBlock(css, js)

Inline `<style>` + `<script>` asset block appended to every page AST.
Storing the full asset text here makes the build hermetic — no file
copying or Artifacts.toml configuration is required.
"""
struct TabsAssetBlock <: Documenter.AbstractDocumenterBlock
    css::String
    js::String
end

# ---------------------------------------------------------------------------
# MarkdownAST container declarations
# NOTE: must come after *all* three types are defined to avoid forward
#       reference errors (Julia evaluates top-level statements in order).
# ---------------------------------------------------------------------------

# TabsBlock: container that only holds TabPanelBlock children
MarkdownAST.iscontainer(::TabsBlock) = true
MarkdownAST.can_contain(::TabsBlock, ::MarkdownAST.AbstractElement) = false
MarkdownAST.can_contain(::TabsBlock, ::TabPanelBlock) = true

# TabPanelBlock: container that accepts any standard block element
MarkdownAST.iscontainer(::TabPanelBlock) = true
MarkdownAST.can_contain(::TabPanelBlock, child::MarkdownAST.AbstractElement) =
    isa(child, MarkdownAST.AbstractBlock)

# TabsAssetBlock: leaf node — no children allowed (defaults to false)
