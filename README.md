# typst-infect.nvim

Inject [Typst](https://typst.app/) into Markdown math spans:

```markdown
Inline math: $x^2 + y^2$

$$
sum_(i=1)^n i = (n(n+1))/2
$$
```


![markdown preview](./assets/md-preview.png)

## Requirements

- Neovim 0.11+
- Tree-sitter parsers: `markdown`, `markdown_inline`, and `typst`
- [snacks.nvim](https://github.com/folke/snacks.nvim) 
- `typst`
- ImageMagick, GhostScript

## Installation

### lazy.nvim

```lua
{
  "js0ny/typst-infect.nvim",
  lazy = false,
  dependencies = {
    "folke/snacks.nvim",
  },
}
```

Run `:checkhealth typst-infect` to verify parsers, the Typst executable, and the Snacks Typst image query.

## Development

```bash
just test
just test-snacks /path/to/snacks.nvim
```

## License

SPDX: [MIT](https://spdx.org/licenses/MIT)
