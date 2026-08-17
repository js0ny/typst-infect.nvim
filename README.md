# typst-infect.nvim

Render [Typst](https://typst.app/) content through `snacks.image` in Markdown and [nvim-orgmode](https://github.com/nvim-orgmode/orgmode).

```markdown
Inline math: $x^2 + y^2$

$$
sum_(i=1)^n i = (n(n+1))/2
$$
```

![markdown preview](./assets/md-preview.png)

## Requirements

- Neovim 0.11+
- [snacks.nvim](https://github.com/folke/snacks.nvim)
- `typst`
- ImageMagick and Ghostscript
- For Markdown: the `markdown`, `markdown_inline`, and `typst` Tree-sitter parsers
- For Org: nvim-orgmode and its `org` Tree-sitter parser

## Installation

### lazy.nvim

```lua
{
  "js0ny/typst-infect.nvim",
  lazy = false,
  dependencies = {
    "folke/snacks.nvim",
    "nvim-orgmode/orgmode",
  },
  opts = {
    markdown = {
      enabled = true,
    },
    org = {
      enabled = true,
      variants = {
        inline = true,
        display = true,
        latex_env = false,
        equation_block = false,
        src_blocks = { "typst", "typst_math", "math" },
      },
    },
  },
}
```

`markdown.enabled = true` is the default. To enable the behaviour only in trusted project directories, set it to `false` in the global configuration:

```lua
opts = {
  markdown = {
    enabled = false,
  },
}
```

Then enable it from the project's `.nvim.lua` or `.exrc`:

```lua
require("typst-infect").setup({
  markdown = {
    enabled = true,
  },
})
```

The local configuration must run before a Markdown parser is created. Neovim's `exrc` and local-config trust settings still apply.

### Org variants

Org integration is disabled by default. When enabled, each variant replaces nvim-orgmode's corresponding LaTeX image match with Typst. A disabled variant retains nvim-orgmode's LaTeX behaviour.

Source blocks have fixed semantics:

```org
#+begin_src typst
#set page(width: 20em, height: 10em)
This complete Typst document is compiled unchanged.
#+end_src

#+begin_src typst_math
sum_(i=1)^n i
#+end_src

#+begin_src math
x^2 + y^2
#+end_src
```

`typst` block contents are passed to the Typst compiler unchanged. `typst_math` and `math` contain delimiter-free Typst math and are wrapped in one `$...$` pair. Remove a language from `src_blocks` to stop replacing that source-block variant.

`inline` and `display` support both dollar and Org's `\(...\)` / `\[...\]` forms. Enabling `latex_env` or `equation_block` treats their bodies as delimiter-free Typst math.

### Nix

Using the overlay:

```nix
{
  nixpkgs.overlays = [ inputs.typst-infect.overlays.default ];
}
```

It exposes the plugin as `pkgs.vimPlugins.typst-infect`.

#### Nixvim

Add the module to a Nixvim configuration:

```nix
{
  imports = [ inputs.typst-infect.nixvimModules.default ];

  plugins.typst-infect = {
    enable = true;
    settings = {
      markdown.enabled = true;
      org = {
        enabled = true;
        variants = {
          inline = true;
          display = true;
          latex_env = false;
          equation_block = false;
          src_blocks = [
            "typst"
            "typst_math"
            "math"
          ];
        };
      };
    };
  };
}
```

The Nixvim module enables nvim-orgmode by default when `settings.org.enabled` is true.

Run `:checkhealth typst-infect` to verify enabled parsers, the Typst executable, and the Snacks Typst image query.

## Development

```bash
just test
just test-snacks /path/to/snacks.nvim
just test-org /path/to/snacks.nvim /path/to/org-parser-rtp /path/to/orgmode
```

## License

SPDX: [MIT](https://spdx.org/licenses/MIT)
