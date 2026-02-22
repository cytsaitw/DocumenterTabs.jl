# DocumenterTabs.jl

## Disclaimer: This feature was heavily implemented using Claude Sonnet 4.6.
A plugin for Julia to group multiple blocks of code in a single panel and use tabs to switch between them.
This tutorial walks you through setting up and using **DocumenterTabs.jl** to add
interactive tab panels to your Julia package documentation.

---

## Installation

DocumenterTabs.jl is not yet registered in the General registry.
Install it directly from GitHub:

```julia
using Pkg
Pkg.add(url = "https://github.com/cytsaitw/DocumenterTabs.jl")
```

Or add it to your `docs/` environment:

```bash
cd docs/
julia --project -e 'using Pkg; Pkg.add(url = "https://github.com/cytsaitw/DocumenterTabs.jl")'
```

---

## Setup

Open your `docs/make.jl` and add `DocumenterTabs`:

```julia
using Documenter
using DocumenterTabs          # 1. import the package
using MyPackage               # your package

makedocs(
    sitename = "MyPackage",
    plugins  = [DocumenterTabs.DocumenterTabsPlugin()],   # 2. register the plugin
    pages    = [
        "Home"     => "index.md",
        "Tutorial" => "tutorial.md",
    ],
)

deploydocs(repo = "github.com/MyOrg/MyPackage.jl.git")
```

That is all the configuration you need. No manual asset copying required —
the plugin injects its CSS and JavaScript automatically.

---

## Basic Usage

Inside any `.md` page, write a `!!! tabs` admonition.
Use `##` headings to define the tab labels, and put the tab content below each heading:

```markdown
!!! tabs
    ## First Tab
    Content for the first tab goes here.

    ## Second Tab
    Content for the second tab goes here.
```

The heading level must be `##` (level 2). The text of each heading becomes the tab label.

> **Note:** The `!!! tabs` admonition does **not** display a title bar (unlike `!!! note`).
> The `##` headings inside it are consumed as labels and do not appear as page headings.

---

## Code Tabs (the main use case)

The most common use for DocumenterTabs is showing the same concept in multiple
programming languages or API styles side-by-side.

Write this in your `.md` file:

````markdown
!!! tabs
    ## Julia
    ```julia
    # Create a vector and compute its sum
    v = [1, 2, 3, 4, 5]
    println(sum(v))   # 15
    ```

    ## Python
    ```python
    # Create a list and compute its sum
    v = [1, 2, 3, 4, 5]
    print(sum(v))   # 15
    ```

    ## R
    ```r
    # Create a vector and compute its sum
    v <- c(1, 2, 3, 4, 5)
    print(sum(v))   # 15
    ```
````

This renders as a tab panel with three tabs: **Julia**, **Python**, and **R**.
Each code block is fully syntax-highlighted by Documenter's normal highlighting pipeline.

---

## Tab Syncing

If the same set of tab labels appears on **multiple pages** (or multiple places on one page),
the selection is **automatically synced** across the entire site.

For example, if a reader selects the **"Python"** tab anywhere, every other tab group
that has a "Python" option will also switch to "Python" — even after navigating to a
different page. The preference is stored in `localStorage` and persists across browser
sessions.

The sync key is determined by the **sorted set of labels**, so these two groups will sync:

```markdown
!!! tabs
    ## Julia
    Some Julia code.

    ## Python
    Some Python code.
```

```markdown
!!! tabs
    ## Julia
    More Julia content on another page.

    ## Python
    More Python content on another page.
```

But this group will **not** sync with the above (different label set):

```markdown
!!! tabs
    ## Julia
    Julia only here.

    ## Rust
    Rust content.
```

---

## Rich Tab Content

Tab panels are not limited to code blocks. You can put any Markdown content inside:

````markdown
!!! tabs
    ## Overview
    Tabs support **bold**, *italic*, and `inline code`.

    You can also have:
    - Bullet lists
    - With multiple items

    And even block quotes:
    > This is a note inside a tab.

    ## Code Example
    ```julia
    struct Point
        x::Float64
        y::Float64
    end
    ```

    ## Math
    The Euclidean distance between two points is:

    ```math
    d = \sqrt{(x_2 - x_1)^2 + (y_2 - y_1)^2}
    ```
````

---

## Multiple Tab Groups on One Page

You can have as many `!!! tabs` blocks as you like on a single page.
They are all independent unless they share the same label set (in which case they sync):

````markdown
## Installation options

!!! tabs
    ## Package Manager
    ```bash
    pkg> add MyPackage
    ```

    ## Direct URL
    ```julia
    Pkg.add(url = "https://github.com/...")
    ```

## Usage examples

!!! tabs
    ## Basic
    ```julia
    using MyPackage
    greet("world")
    ```

    ## Advanced
    ```julia
    using MyPackage
    config = Config(verbose = true)
    greet("world", config)
    ```
````

---

## Limitations

- **Search index**: Tab content is currently excluded from Documenter's built-in search
  index. Readers will not find content inside tabs via the search bar.

- **Heading levels**: Only `##` (level-2) headings are recognised as tab labels.
  Other heading levels inside `!!! tabs` are treated as regular content.

- **Nesting**: Nested `!!! tabs` blocks (tabs inside tabs) are not supported.

---

## Quick Reference

| Syntax element | What it does |
|---|---|
| `!!! tabs` | Starts a tab group |
| `## Label` | Defines a new tab with that label |
| Content below heading | Body of that tab panel |
| Same label set on multiple groups | Groups stay in sync via `localStorage` |

```markdown
!!! tabs
    ## Tab A
    Content A

    ## Tab B
    Content B
```
