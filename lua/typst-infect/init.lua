local M = {
  config = {
    markdown = {
      enabled = true,
    },
    org = {
      enabled = false,
      variants = {
        inline = true,
        display = true,
        latex_env = false,
        equation_block = false,
        src_blocks = { 'typst', 'typst_math', 'math' },
      },
    },
  },
}

-- A self-contained query avoids eagerly compiling inherited injections just to disable LaTeX.
local markdown_injection_query = [[
((html_tag) @injection.content
  (#set! injection.language "html")
  (#set! injection.combined))

((latex_block
  (latex_span_delimiter) @_start
  (latex_span_delimiter) @_end) @injection.content
  (#eq? @_start "$")
  (#eq? @_end "$")
  (#set! injection.language "typst")
  (#set! injection.include-children))

((latex_block
  (latex_span_delimiter) @_start
  (latex_span_delimiter) @_end) @injection.content
  (#eq? @_start "$$")
  (#eq? @_end "$$")
  ; Typst needs one delimiter pair; `$$` would be parsed as two empty equations.
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "typst")
  (#set! injection.include-children))
]]

local org_image_link_query = [[
(link url: (expr) @image.src
  (#gsub! @image.src "^file:" "")
  (#match? @image.src "(png|jpg|jpeg|gif|bmp|webp|tiff|heic|avif|mp4|mov|avi|mkv|webm|pdf|svg)$"))
]]

local function org_source_block_query(language, image_language, extension)
  return ([=[
((block
  name: (expr) @_name
  .
  parameter: (expr) @_lang
  contents: (contents) @image.content) @image
  (#any-of? @_name "src" "SRC")
  (#eq? @_lang %q)
  (#set! image.lang %q)
  (#set! image.ext %q))
]=]):format(language, image_language, extension)
end

local function org_math_node_query(node)
  return ([=[
((%s
  contents: (contents) @image.content) @image
  (#set! image.lang "typst_infect")
  (#set! image.ext "math.typ"))
]=]):format(node)
end

local function org_latex_node_query(node)
  return ([=[
(%s
  (#set! injection.language "latex")
  (#set! image.ext "math.tex")) @image.content @image
]=]):format(node)
end

local function org_equation_query(image_language, extension, full_range)
  local image_capture = full_range and ' @image' or ''
  return ([=[
((block
  name: (expr) @_name
  contents: (contents) @image.content)%s
  (#any-of? @_name "equation" "EQUATION")
  (#set! image.lang %q)
  (#set! image.ext %q))
]=]):format(image_capture, image_language, extension)
end

local function build_org_images_query(variants)
  local queries = { org_image_link_query }
  local source_blocks = {}
  for _, language in ipairs(variants.src_blocks) do
    source_blocks[language] = true
  end

  if source_blocks.typst then
    queries[#queries + 1] = org_source_block_query('typst', 'typst_infect_document', 'math.typ')
  end
  for _, language in ipairs({ 'typst_math', 'math' }) do
    if source_blocks[language] then
      queries[#queries + 1] = org_source_block_query(language, 'typst_infect', 'math.typ')
    end
  end

  queries[#queries + 1] = org_source_block_query('latex', 'latex', 'math.tex')
  if not source_blocks.math then
    queries[#queries + 1] = org_source_block_query('math', 'latex', 'math.tex')
  end

  queries[#queries + 1] = variants.equation_block
      and org_equation_query('typst_infect', 'math.typ', true)
    or org_equation_query('latex', 'math.tex', false)
  queries[#queries + 1] = variants.latex_env and org_math_node_query('latex_env')
    or org_latex_node_query('latex_env')
  queries[#queries + 1] = variants.inline and org_math_node_query('inline_math_block')
    or org_latex_node_query('inline_math_block')
  queries[#queries + 1] = variants.display and org_math_node_query('display_math_block')
    or org_latex_node_query('display_math_block')

  return table.concat(queries, '\n')
end

local function position_lte(left_row, left_col, right_row, right_col)
  return left_row < right_row or (left_row == right_row and left_col <= right_col)
end

local function contains(outer, inner)
  return position_lte(outer[1], outer[2], inner[1], inner[2])
    and position_lte(inner[3], inner[4], outer[3], outer[4])
end

local function deduplicate(images)
  local infected = {}
  for _, image in ipairs(images) do
    if image._typst_infect and image.range then
      infected[#infected + 1] = image.range
    end
  end

  if #infected == 0 then
    return images
  end

  return vim.tbl_filter(function(image)
    if image._typst_infect or image.type ~= 'math' or not image.range then
      return true
    end
    for _, range in ipairs(infected) do
      if contains(range, image.range) then
        return false
      end
    end
    return true
  end, images)
end

local function integration_enabled()
  return M.config.markdown.enabled or M.config.org.enabled
end

function M.setup_snacks()
  if not integration_enabled() or not _G.Snacks then
    return false
  end

  local ok, doc = pcall(require, 'snacks.image.doc')
  if not ok or doc._typst_infect_configured then
    return ok
  end

  local typst_transform = doc.transforms.typst
  if not typst_transform then
    return false
  end

  doc.transforms.typst_infect = function(image, context)
    image._typst_infect = true
    image.content = '$' .. image.content .. '$'
    return typst_transform(image, context)
  end

  doc.transforms.typst_infect_document = function(image)
    image._typst_infect = true
  end

  -- Infected parent matches own the conceal range, so discard injected math children.
  local find = doc.find
  doc.find = function(buffer, callback, options)
    return find(buffer, function(images)
      callback(deduplicate(images))
    end, options)
  end

  doc._typst_infect_configured = true
  return true
end

local function validate_options(options)
  vim.validate('options', options, 'table')
  vim.validate('options.markdown', options.markdown, 'table', true)
  vim.validate('options.org', options.org, 'table', true)

  if options.markdown then
    vim.validate('options.markdown.enabled', options.markdown.enabled, 'boolean', true)
  end
  if not options.org then
    return
  end

  vim.validate('options.org.enabled', options.org.enabled, 'boolean', true)
  vim.validate('options.org.variants', options.org.variants, 'table', true)
  if not options.org.variants then
    return
  end

  local variants = options.org.variants
  for _, name in ipairs({ 'inline', 'display', 'latex_env', 'equation_block' }) do
    vim.validate('options.org.variants.' .. name, variants[name], 'boolean', true)
  end
  vim.validate('options.org.variants.src_blocks', variants.src_blocks, 'table', true)
  if not variants.src_blocks then
    return
  end

  local supported = { typst = true, typst_math = true, math = true }
  for index, language in ipairs(variants.src_blocks) do
    vim.validate(('options.org.variants.src_blocks[%d]'):format(index), language, 'string')
    if not supported[language] then
      error(('unsupported Org source block language: %s'):format(language))
    end
  end
end

function M.setup(options)
  if vim.fn.has('nvim-0.11') == 0 then
    error('typst-infect requires Neovim 0.11 or newer')
  end

  options = options or {}
  validate_options(options)

  local config = vim.tbl_deep_extend('force', {}, M.config, options)
  if options.org and options.org.variants and options.org.variants.src_blocks then
    config.org.variants.src_blocks = vim.deepcopy(options.org.variants.src_blocks)
  end
  M.config = config

  if not M.predicate_registered then
    vim.treesitter.query.add_predicate('typst-infect-enabled?', function()
      return M.config.markdown.enabled
    end)
    M.predicate_registered = true
  end

  vim.treesitter.query.set(
    'markdown_inline',
    'injections',
    M.config.markdown.enabled and markdown_injection_query or ';; extends\n'
  )
  vim.treesitter.query.set(
    'org',
    'images',
    M.config.org.enabled and build_org_images_query(M.config.org.variants) or ';; extends\n'
  )

  local group = vim.api.nvim_create_augroup('typst-infect', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'markdown', 'org' },
    callback = function(event)
      local enabled = event.match == 'markdown' and M.config.markdown.enabled
        or event.match == 'org' and M.config.org.enabled
      if enabled then
        M.setup_snacks()
        vim.schedule(M.setup_snacks)
      end
    end,
  })

  M.configured = true
end

return M
