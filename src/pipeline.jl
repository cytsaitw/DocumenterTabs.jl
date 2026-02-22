# pipeline.jl — Documenter builder pipeline stages for DocumenterTabs.jl
#
# Registers two pipeline stages with Documenter's Selectors framework:
#
#   TabsTransformer   (order 1.5) — rewrites !!! tabs admonitions in all pages
#   TabsAssetInjector (order 1.6) — injects inline CSS + JS into every page

# ---------------------------------------------------------------------------
# Asset file paths (resolved relative to this package's src/ directory)
# ---------------------------------------------------------------------------

const _CSS_PATH = joinpath(@__DIR__, "assets", "tabs.css")
const _JS_PATH = joinpath(@__DIR__, "assets", "tabs.js")

# ---------------------------------------------------------------------------
# Stage 1 — TabsTransformer
# ---------------------------------------------------------------------------

"""
Documenter pipeline stage that walks every page's MarkdownAST and converts
`!!! tabs` admonition nodes into `TabsBlock` / `TabPanelBlock` subtrees.

Runs at order `1.5`, before Documenter's own `ExpandTemplates` stage (5.0),
so tab content is normalised before any further processing occurs.
"""
abstract type TabsTransformer <: Documenter.Builder.DocumentPipeline end

Selectors.order(::Type{TabsTransformer}) = 1.5

function Selectors.runner(::Type{TabsTransformer}, doc::Documenter.Document)
    for page in values(doc.blueprint.pages)
        _transform_page!(page.mdast)
    end
end

# ---------------------------------------------------------------------------
# Stage 2 — TabsAssetInjector
# ---------------------------------------------------------------------------

"""
Documenter pipeline stage that reads `tabs.css` and `tabs.js` from the
package's `src/assets/` directory and appends a `TabsAssetBlock` node to
every page's AST so that the HTML writer emits the assets inline.

Runs at order `1.6`, immediately after `TabsTransformer`.
The stage is a no-op when `DocumenterTabsPlugin` has not been registered.
"""
abstract type TabsAssetInjector <: Documenter.Builder.DocumentPipeline end

Selectors.order(::Type{TabsAssetInjector}) = 1.6

function Selectors.runner(::Type{TabsAssetInjector}, doc::Documenter.Document)
    # No-op when the plugin was not registered by the user.
    Documenter.getplugin(doc, DocumenterTabsPlugin) === nothing && return

    css = isfile(_CSS_PATH) ? read(_CSS_PATH, String) : ""
    js = isfile(_JS_PATH) ? read(_JS_PATH, String) : ""

    asset_element = TabsAssetBlock(css, js)
    for page in values(doc.blueprint.pages)
        push!(page.mdast.children, Node(asset_element))
    end
end
