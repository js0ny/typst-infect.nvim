local snacks_path = assert(vim.env.SNACKS_PATH, 'SNACKS_PATH is required')
local org_parser_rtp = assert(vim.env.ORG_PARSER_RTP, 'ORG_PARSER_RTP is required')
local orgmode_path = assert(vim.env.ORGMODE_PATH, 'ORGMODE_PATH is required')
vim.opt.runtimepath:prepend(org_parser_rtp)
vim.opt.runtimepath:prepend(orgmode_path)
vim.opt.runtimepath:prepend(snacks_path)
vim.opt.runtimepath:prepend(vim.uv.cwd())

local typst_infect = require('typst-infect')
typst_infect.setup({
  markdown = { enabled = false },
  org = {
    enabled = true,
    variants = {
      inline = true,
      display = true,
      latex_env = false,
      equation_block = false,
      src_blocks = { 'typst', 'typst_math', 'math' },
    },
  },
})
require('snacks').setup({ image = { enabled = true } })
require('orgmode').setup({})

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  'Inline $x + y$.',
  '$$ x+y $$',
  '\\(z+w\\)',
  '\\[a+b\\]',
  '',
  '#+begin_src typst',
  '#set page(width: 10em, height: 10em)',
  'Hello $x + y$',
  '#+end_src',
  '',
  '#+begin_src typst_math',
  'sum_(i=1)^n i',
  '#+end_src',
  '',
  '#+begin_src math',
  'x + y',
  '#+end_src',
  '',
  '#+begin_equation',
  'x+y',
  '#+end_equation',
  '',
  '\\begin{equation}',
  'x+y',
  '\\end{equation}',
})
vim.bo[buffer].filetype = 'org'

local doc = require('snacks.image.doc')
assert(doc._typst_infect_configured, 'FileType did not configure Snacks.image integration')

local function find_images()
  local result
  doc.find(buffer, function(images)
    result = images
  end)
  vim.wait(5000, function()
    return result ~= nil
  end, 10)
  return assert(result, 'Snacks.image lookup timed out')
end

local function image_at(images, line)
  return assert(
    vim.iter(images):find(function(image)
      return image.range[1] == line
    end),
    ('no image starts at line %d'):format(line)
  )
end

local images = find_images()
assert(#images == 9, ('expected 9 Org images, got %d'):format(#images))

for line = 1, 4 do
  local image = image_at(images, line)
  assert(image.lang == 'typst_infect', ('line %d was not rendered with Typst'):format(line))
  assert(image.content:find('$', 1, true), ('line %d was not wrapped as Typst math'):format(line))
end

local document = image_at(images, 6)
assert(document.lang == 'typst_infect_document', 'Typst source block was transformed as math')
assert(
  document.content == '#set page(width: 10em, height: 10em)\nHello $x + y$\n',
  'Typst source block content was modified'
)
assert(vim.deep_equal(document.range, { 6, 0, 9, 9 }), 'Typst source block range is incomplete')

for _, line in ipairs({ 11, 15 }) do
  local image = image_at(images, line)
  assert(image.lang == 'typst_infect', ('source block at line %d was not Typst math'):format(line))
  assert(image.content:find('$', 1, true), ('source block at line %d was not wrapped'):format(line))
end

assert(image_at(images, 20).lang == 'latex', 'disabled equation variant did not preserve LaTeX')
assert(image_at(images, 23).lang == 'latex', 'disabled latex_env variant did not preserve LaTeX')

if vim.fn.executable('typst') == 1 then
  for _, image in ipairs(images) do
    if image.ext == 'math.typ' then
      local output = vim.fn.tempname() .. '.pdf'
      local process =
        vim.system({ 'typst', 'compile', '--format', 'pdf', image.src, output }):wait()
      assert(process.code == 0, process.stderr)
      vim.uv.fs_unlink(output)
    end
  end
end

typst_infect.setup({
  org = {
    variants = {
      latex_env = true,
      equation_block = true,
    },
  },
})
images = find_images()
assert(image_at(images, 19).lang == 'typst_infect', 'equation variant did not switch to Typst')
assert(image_at(images, 23).lang == 'typst_infect', 'latex_env variant did not switch to Typst')

typst_infect.setup({ org = { enabled = false } })
images = find_images()
assert(image_at(images, 1).lang == 'latex', 'disabling Org did not restore inline LaTeX')
assert(image_at(images, 2).lang == 'latex', 'disabling Org did not restore display LaTeX')
assert(image_at(images, 16).lang == 'latex', 'disabling Org did not restore math source LaTeX')

print('typst-infect: Org Snacks.image tests passed')
