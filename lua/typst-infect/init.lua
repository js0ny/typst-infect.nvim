local M = {}

local injection_query = [[
;; extends

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

local function is_latex_injection(directive)
  return directive[1] == "set!"
    and directive[2] == "injection.language"
    and directive[3] == "latex"
end

local function position_lte(left_row, left_col, right_row, right_col)
  return left_row < right_row or (left_row == right_row and left_col <= right_col)
end

local function contains(outer, inner)
  return position_lte(outer[1], outer[2], inner[1], inner[2])
    and position_lte(inner[3], inner[4], outer[3], outer[4])
end

local function deduplicate(images)
  local markdown_math = {}
  for _, image in ipairs(images) do
    if image._typst_infect and image.range then
      markdown_math[#markdown_math + 1] = image.range
    end
  end

  if #markdown_math == 0 then
    return images
  end

  return vim.tbl_filter(function(image)
    if image._typst_infect or image.lang ~= "typst" or image.type ~= "math" or not image.range then
      return true
    end
    for _, range in ipairs(markdown_math) do
      if contains(range, image.range) then
        return false
      end
    end
    return true
  end, images)
end

function M.setup_snacks()
  if not _G.Snacks then
    return false
  end

  local ok, doc = pcall(require, "snacks.image.doc")
  if not ok or doc._typst_infect_configured then
    return ok
  end

  local typst_transform = doc.transforms.typst
  if not typst_transform then
    return false
  end

  doc.transforms.typst_infect = function(image, context)
    image._typst_infect = true
    image.content = "$" .. image.content .. "$"
    return typst_transform(image, context)
  end

  -- The Markdown match owns the full conceal range, so discard its injected child match.
  local find = doc.find
  doc.find = function(buffer, callback, options)
    return find(buffer, function(images)
      callback(deduplicate(images))
    end, options)
  end

  doc._typst_infect_configured = true
  return true
end

function M.setup()
  if vim.fn.has("nvim-0.11") == 0 then
    error("typst-infect requires Neovim 0.11 or newer")
  end

  vim.treesitter.query.set("markdown_inline", "injections", injection_query)

  local query = assert(vim.treesitter.query.get("markdown_inline", "injections"))
  if not query.query.disable_pattern then
    error("typst-infect requires TSQuery:disable_pattern()")
  end

  for pattern, directives in pairs(query.info.patterns) do
    for _, directive in ipairs(directives) do
      if is_latex_injection(directive) then
        query.query:disable_pattern(pattern)
        break
      end
    end
  end

  local group = vim.api.nvim_create_augroup("typst-infect", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function()
      vim.schedule(M.setup_snacks)
    end,
  })

  M.setup_snacks()
  M.configured = true
end

return M
