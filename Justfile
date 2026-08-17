nvim := env_var_or_default("NVIM", "nvim")

default: test

test:
    {{nvim}} --headless -u NONE -l tests/injection.lua

test-snacks snacks_path:
    SNACKS_PATH="{{snacks_path}}" {{nvim}} --headless -u NONE -l tests/snacks.lua

test-org snacks_path org_parser_rtp orgmode_path:
    SNACKS_PATH="{{snacks_path}}" ORG_PARSER_RTP="{{org_parser_rtp}}" ORGMODE_PATH="{{orgmode_path}}" {{nvim}} --headless -u NONE -l tests/org.lua
