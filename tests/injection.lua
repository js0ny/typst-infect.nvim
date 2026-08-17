vim.opt.runtimepath:prepend(vim.uv.cwd())
require('typst-infect').setup({ markdown = { enabled = true } })

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  'Inline $x^2 + y^2$ end.',
  '',
  '$$',
  'sum_(i=1)^n i = (n(n+1))/2',
  '$$',
})
vim.bo[buffer].filetype = 'markdown'

local parser = assert(vim.treesitter.get_parser(buffer, 'markdown'))
parser:parse(true)

local languages = {}
local typst_trees = {}
parser:for_each_tree(function(tree, language_tree)
  local language = language_tree:lang()
  languages[language] = true
  if language == 'typst' then
    typst_trees[#typst_trees + 1] = tree
  end
end)

assert(languages.typst, 'Typst was not injected')
assert(not languages.latex, 'LaTeX was still injected')
assert(#typst_trees == 2, ('expected 2 Typst trees, got %d'):format(#typst_trees))

for _, tree in ipairs(typst_trees) do
  assert(tree:root():sexpr():find('(math', 1, true), 'injected source did not parse as Typst math')
end

require('typst-infect').setup({ markdown = { enabled = false } })
local disabled_query = assert(vim.treesitter.query.get('markdown_inline', 'injections'))
local has_latex = false
local has_typst = false
for _, directives in pairs(disabled_query.info.patterns) do
  for _, directive in ipairs(directives) do
    if directive[1] == 'set!' and directive[2] == 'injection.language' then
      has_latex = has_latex or directive[3] == 'latex'
      has_typst = has_typst or directive[3] == 'typst'
    end
  end
end
assert(has_latex, 'disabling Markdown did not restore the LaTeX injection')
assert(not has_typst, 'Typst injection remained configured')

print('typst-infect: injection tests passed')
