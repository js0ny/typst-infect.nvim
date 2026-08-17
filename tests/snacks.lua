local snacks_path = assert(vim.env.SNACKS_PATH, 'SNACKS_PATH is required')
vim.opt.runtimepath:prepend(snacks_path)
vim.opt.runtimepath:prepend(vim.uv.cwd())

local typst_infect = require('typst-infect')
typst_infect.setup({ markdown = { enabled = true } })
require('snacks').setup({ image = { enabled = true } })
assert(typst_infect.setup_snacks(), 'failed to configure Snacks.image integration')

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  'Inline $x^2 + y^2$ end.',
  '',
  '$$',
  'sum_(i=1)^n i = (n(n+1))/2',
  '$$',
})
vim.bo[buffer].filetype = 'markdown'

local result
require('snacks.image.doc').find(buffer, function(images)
  result = images
end)

vim.wait(5000, function()
  return result ~= nil
end, 10)

assert(result, 'Snacks.image lookup timed out')
assert(#result == 2, ('expected 2 images, got %d'):format(#result))
for _, image in ipairs(result) do
  assert(image.lang == 'typst_infect', ('expected typst_infect image, got %s'):format(image.lang))
  assert(image.ext == 'math.typ', ('expected math.typ, got %s'):format(image.ext))
  assert(
    not image.content:find('$$', 1, true),
    'Typst source still contains a double-dollar delimiter'
  )

  if vim.fn.executable('typst') == 1 then
    local output = vim.fn.tempname() .. '.pdf'
    local process = vim.system({ 'typst', 'compile', '--format', 'pdf', image.src, output }):wait()
    assert(process.code == 0, process.stderr)
    vim.uv.fs_unlink(output)
  end
end

local block = assert(vim.iter(result):find(function(image)
  return image.range[1] == 3
end))
assert(
  vim.deep_equal(block.range, { 3, 0, 5, 2 }),
  'display math does not own the full Markdown range'
)
assert(
  block.content:find('$\nsum_(i=1)^n i = (n(n+1))/2\n$', 1, true),
  'display math was not wrapped'
)

typst_infect.setup({ markdown = { enabled = false } })
local disabled_result
require('snacks.image.doc').find(buffer, function(images)
  disabled_result = images
end)
vim.wait(5000, function()
  return disabled_result ~= nil
end, 10)
assert(disabled_result, 'disabled Snacks.image lookup timed out')
assert(not vim.iter(disabled_result):any(function(image)
  return image.lang == 'typst_infect'
end), 'Markdown rendering remained enabled')

print('typst-infect: Snacks.image tests passed')
