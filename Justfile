nvim := env_var_or_default("NVIM", "nvim")

default: test

test:
    {{nvim}} --headless -u NONE -l tests/injection.lua

test-snacks snacks_path:
    SNACKS_PATH="{{snacks_path}}" {{nvim}} --headless -u NONE -l tests/snacks.lua
