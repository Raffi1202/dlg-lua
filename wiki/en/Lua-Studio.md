# Lua-Studio

With [Lua-Studio](https://github.com/Raffi1202/lua-studio) you arrange the FLIGHT page on your PC (values, layout, limits) and transfer it to the radio. Without a studio file DLG shows its own FLIGHT page. The F3K and LAUNCHES pages are not changed by the studio.

## One layout for all models

In Lua-Studio choose «For all models (default)» when transferring. The file is then called `Standard.dlg.lua` and applies to every model without its own file. Order: 1. choice in the menu «Studio layout», 2. the model's file (model name.dlg.lua, e.g. `Segler_A.dlg.lua`), 3. `Standard.dlg.lua`, 4. built-in page. The menu shows the entry «Default (all models)»; «automatic» shows in brackets what applies right now. Changes in the menu on the radio apply to the current model only. If a model itself is named «Standard», the file counts as its model file.
