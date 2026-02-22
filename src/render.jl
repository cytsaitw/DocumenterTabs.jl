# render.jl — HTML rendering and search-index integration for DocumenterTabs.jl
#
# Defines:
#   • domify()     methods for TabsBlock, TabPanelBlock, TabsAssetBlock
#   • mdflatten()  no-ops to keep Documenter's search indexer happy

# ---------------------------------------------------------------------------
# HTMLWriter.domify — convert AST nodes to Documenter DOM elements
# ---------------------------------------------------------------------------

"""
    domify(dctx, node, ::TabsBlock)

Renders the full tab widget:
- One `<div class="doc-tabs">` container (carries `data-tabs-group`).
- One `<div class="doc-tabs__labels">` row of `<button>` elements.
- Then each child `TabPanelBlock` is rendered via its own `domify` method.

The `data-tabs-group` attribute is a `|`-joined, sorted string of all label
names so that any two tab groups with the same label set will sync together
via `localStorage` (handled in `tabs.js`).
"""
function Documenter.HTMLWriter.domify(dctx::DCtx, node::Node, el::TabsBlock)
    DOM.@tags div button

    # Stable group key: sorted labels joined by "|"
    group_key = join(sort(el.labels), "|")

    # One <button> per label
    label_btns = [
        button[
            ".doc-tabs__label",
            Symbol("data-tab")=>string(i - 1),
            Symbol("data-tabs-group")=>group_key,
        ](label)
        for (i, label) in enumerate(el.labels)
    ]

    # Recursively render each TabPanelBlock child
    panel_divs = map(collect(node.children)) do panel_node
        Documenter.HTMLWriter.domify(dctx, panel_node, panel_node.element)
    end

    div[
        ".doc-tabs",
        Symbol("data-tabs-group")=>group_key,
    ](
        div[".doc-tabs__labels"](label_btns...),
        panel_divs...,
    )
end

"""
    domify(dctx, node, ::TabPanelBlock)

Renders one tab panel as `<div class="doc-tabs__panel" data-tab="N">`.
Child nodes (code blocks, paragraphs, etc.) are rendered recursively by
Documenter's own `domify` machinery.
"""
function Documenter.HTMLWriter.domify(dctx::DCtx, node::Node, el::TabPanelBlock)
    DOM.@tags div
    inner = Documenter.HTMLWriter.domify(dctx, node.children)
    div[
        ".doc-tabs__panel",
        Symbol("data-tab")=>string(el.index),
    ](inner...)
end

"""
    domify(::DCtx, ::Node, ::TabsAssetBlock)

Emits an inline `<style>` block and a `<script>` block carrying the full
CSS and JavaScript for the tab widget.  Inlining avoids any need for
`deploydocs` asset configuration.
"""
function Documenter.HTMLWriter.domify(::DCtx, ::Node, el::TabsAssetBlock)
    DOM.@tags style script
    [style(el.css), script(el.js)]
end

# ---------------------------------------------------------------------------
# MDFlatten — keep search indexing safe
# ---------------------------------------------------------------------------
# Documenter's built-in fallback for AbstractDocumenterBlock errors at build
# time.  We override it for our three types as a no-op so the search index
# build succeeds while silently skipping tab content.

Documenter.MDFlatten.mdflatten(io, ::Node, ::TabsBlock) = nothing
Documenter.MDFlatten.mdflatten(io, ::Node, ::TabPanelBlock) = nothing
Documenter.MDFlatten.mdflatten(io, ::Node, ::TabsAssetBlock) = nothing
