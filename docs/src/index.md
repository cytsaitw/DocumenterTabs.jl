# DocumenterTabs.jl Example

## Code Tabs

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

## Tab Syncing

!!! tabs
    ## Julia
    ```julia
    println("Hello, World!")
    ```

    ## Python
    ```python
    print("Hello, World!")
    ```

    ## Rust
    ```rust
    println!("Hello, World!");
    ```

## Rich Tab Content

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