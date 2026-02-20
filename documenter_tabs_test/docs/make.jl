using Documenter
using DocumenterTabs          # 1. import the package

makedocs(
    sitename = "Test",
    plugins  = [DocumenterTabs.DocumenterTabsPlugin()],   # 2. register the plugin
    pages    = [
        "Home"     => "index.md",
        "Tutorial" => "tutorial.md",
    ],
)

