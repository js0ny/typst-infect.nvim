if vim.g.loaded_typst_infect then
  return
end
vim.g.loaded_typst_infect = true

local ok, err = pcall(require('typst-infect').setup)
if not ok then
  vim.schedule(function()
    vim.notify(err, vim.log.levels.ERROR, { title = 'typst-infect' })
  end)
end
