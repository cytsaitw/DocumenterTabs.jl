# transform.jl — AST transformation: !!! tabs admonition → TabsBlock
#
# Contains the helpers for extracting plain text from heading nodes and the
# core mutation that rewrites a single `!!! tabs` admonition node in-place
# into a `TabsBlock` / `TabPanelBlock` subtree.

# ---------------------------------------------------------------------------
# Helpers: extract plain text label from a heading node
# ---------------------------------------------------------------------------

"""
    _heading_text(heading_node) -> String

Recursively collects the plain-text content of a `MarkdownAST.Heading` node,
stripping away inline markup so only the raw string remains.
This string becomes the tab label.
"""
function _heading_text(heading_node::Node)
    buf = IOBuffer()
    _flatten!(buf, heading_node)
    strip(String(take!(buf)))
end

"""
    _flatten!(io, node)

Recursively writes the plain-text representation of `node` (and all its
descendants) to `io`, handling `Text`, `Code`, `SoftBreak`, and `LineBreak`
inline elements.  All other inline containers are descended into.
"""
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
# Core transformation: one !!! tabs admonition node → TabsBlock subtree
# ---------------------------------------------------------------------------

"""
    _transform_tabs_node!(node)

Mutates `node` in-place, transforming a `!!! tabs` admonition into a
`TabsBlock` whose children are `TabPanelBlock` nodes wrapping the original
content blocks.

Algorithm:
1. Snapshot all current children.
2. Walk them: each `Heading` child starts a new tab; all other block nodes
   are collected into the current panel's content list.
3. Replace the node's element with `TabsBlock(labels)`.
4. Detach all existing children.
5. Re-attach panel content wrapped inside fresh `TabPanelBlock` nodes.
"""
function _transform_tabs_node!(node::Node)
    # Snapshot children before we modify anything
    children = collect(node.children)

    labels = String[]
    panels = Vector{Vector{Node}}()
    current = Vector{Node}()

    for child in children
        if child.element isa MarkdownAST.Heading
            # A heading signals the start of a new tab.
            # Save the accumulated content for the previous panel (if any).
            if !isempty(labels)
                push!(panels, current)
                current = Vector{Node}()
            end
            push!(labels, _heading_text(child))
        else
            push!(current, child)
        end
    end
    # Flush the last panel's accumulated content.
    push!(panels, current)

    # Swap the element type on the existing node (no new parent node needed).
    node.element = TabsBlock(labels)

    # Detach every existing child (headings + content blocks).
    for child in collect(node.children)
        MarkdownAST.unlink!(child)
    end

    # Re-attach panel content, each panel wrapped in a TabPanelBlock node.
    for (i, panel_children) in enumerate(panels)
        panel_node = Node(TabPanelBlock(i - 1))   # 0-based index
        for child in panel_children
            MarkdownAST.unlink!(child)             # detach from temporary list
            push!(panel_node.children, child)
        end
        push!(node.children, panel_node)
    end
end

# ---------------------------------------------------------------------------
# Page-level walk: applies _transform_tabs_node! to every matching node
# ---------------------------------------------------------------------------

"""
    _transform_page!(root)

Traverses the full MarkdownAST rooted at `root` in pre-order and replaces
every `!!! tabs` admonition node with a `TabsBlock` subtree.
"""
function _transform_page!(root::Node)
    for node in collect(AbstractTrees.PreOrderDFS(root))
        el = node.element
        if el isa MarkdownAST.Admonition && el.category == "tabs"
            _transform_tabs_node!(node)
        end
    end
end
