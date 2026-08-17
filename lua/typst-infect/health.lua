local M = {}

local function has_parser(language)
  local ok, result = pcall(vim.treesitter.language.add, language)
  return ok and result ~= nil
end

function M.check()
  vim.health.start("typst-infect")

  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim 0.11+")
  else
    vim.health.error("Neovim 0.11+ is required")
  end

  for _, language in ipairs({ "markdown", "markdown_inline", "typst" }) do
    if has_parser(language) then
      vim.health.ok(("Tree-sitter parser `%s` is installed"):format(language))
    else
      vim.health.error(("Tree-sitter parser `%s` is missing"):format(language))
    end
  end

  if vim.fn.executable("typst") == 1 then
    vim.health.ok("`typst` executable is available")
  else
    vim.health.warn("`typst` is required for Snacks.image rendering")
  end

  local images = vim.api.nvim_get_runtime_file("queries/typst/images.scm", true)
  local compatible = false
  for _, file in ipairs(images) do
    local handle = io.open(file, "r")
    if handle then
      local content = handle:read("*a")
      handle:close()
      if content:find("math.typ", 1, true) then
        compatible = true
        break
      end
    end
  end

  if compatible then
    vim.health.ok("Snacks.image Typst math query is available")
  else
    vim.health.info("Snacks.image integration is not available")
  end
end

return M
