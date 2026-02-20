using Test
using Markdown
using MarkdownAST: MarkdownAST, Node, @ast
import AbstractTrees

# We test the transformation functions directly, without a full Documenter build.
# Load the module code under test.
include(joinpath(@__DIR__, "..", "src", "DocumenterTabs.jl"))
using .DocumenterTabs: DocumenterTabs, TabsBlock, TabPanelBlock, _transform_tabs_node!, _heading_text

# ---------------------------------------------------------------------------
# Helper: convert a Markdown string into a MarkdownAST document tree
# ---------------------------------------------------------------------------
function parse_md(src::String)
    md = Markdown.parse(src)
    return convert(Node, md)
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@testset "DocumenterTabs" begin

    @testset "Heading text extraction" begin
        doc = parse_md("## Hello **World**")
        # Find the heading node
        heading = first(child for child in doc.children
                        if child.element isa MarkdownAST.Heading)
        @test _heading_text(heading) == "Hello World"
    end

    @testset "Tab transformation: basic labels" begin
        src = """
        !!! tabs
            ## Julia
            Hello from Julia.

            ## Python
            Hello from Python.
        """
        doc = parse_md(src)

        # Find the admonition before transformation
        adm = first(
            child for child in doc.children
            if child.element isa MarkdownAST.Admonition
        )
        @test adm.element.category == "tabs"

        # Run the transformer
        DocumenterTabs._transform_page!(doc)

        # The node should now be a TabsBlock
        tabs = first(
            child for child in doc.children
            if child.element isa TabsBlock
        )
        @test tabs.element.labels == ["Julia", "Python"]
    end

    @testset "Tab transformation: panel count" begin
        src = """
        !!! tabs
            ## Tab One
            Content one.

            ## Tab Two
            Content two.

            ## Tab Three
            Content three.
        """
        doc = parse_md(src)
        DocumenterTabs._transform_page!(doc)

        tabs = first(
            child for child in doc.children
            if child.element isa TabsBlock
        )
        panels = [child for child in tabs.children
                  if child.element isa TabPanelBlock]
        @test length(panels) == 3
        @test [p.element.index for p in panels] == [0, 1, 2]
    end

    @testset "Tab transformation: non-tabs admonitions untouched" begin
        src = """
        !!! note "Note title"
            This is a regular note.
        """
        doc = parse_md(src)
        DocumenterTabs._transform_page!(doc)

        adm = first(
            child for child in doc.children
            if child.element isa MarkdownAST.Admonition
        )
        @test adm.element.category == "note"   # unchanged
    end

    @testset "Tab transformation: code blocks preserved in panels" begin
        src = """
        !!! tabs
            ## Julia
            ```julia
            println("hello")
            ```

            ## Python
            ```python
            print("hello")
            ```
        """
        doc = parse_md(src)
        DocumenterTabs._transform_page!(doc)

        tabs = first(
            child for child in doc.children
            if child.element isa TabsBlock
        )

        # Each panel should have a code block child
        panels = [child for child in tabs.children
                  if child.element isa TabPanelBlock]
        @test length(panels) == 2

        for panel in panels
            code_nodes = [
                child for child in AbstractTrees.Leaves(panel)
                if child.element isa MarkdownAST.CodeBlock
            ]
            @test !isempty(code_nodes)
        end

        # Check language info is preserved
        julia_panel = panels[1]
        julia_code = first(
            child for child in AbstractTrees.Leaves(julia_panel)
            if child.element isa MarkdownAST.CodeBlock
        )
        @test julia_code.element.info == "julia"
    end

    @testset "Tab transformation: multiple tab groups on one page" begin
        src = """
        !!! tabs
            ## A
            Panel A1.

            ## B
            Panel B1.

        Some text between groups.

        !!! tabs
            ## X
            Panel X.

            ## Y
            Panel Y.
        """
        doc = parse_md(src)
        DocumenterTabs._transform_page!(doc)

        tab_nodes = [
            child for child in doc.children
            if child.element isa TabsBlock
        ]
        @test length(tab_nodes) == 2
        @test tab_nodes[1].element.labels == ["A", "B"]
        @test tab_nodes[2].element.labels == ["X", "Y"]
    end

end
