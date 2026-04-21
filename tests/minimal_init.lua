-- Minimal init for testing
vim.cmd([[set runtimepath+=.]])

-- Support common plenary install locations
local plenary_paths = {
  vim.fn.expand('~/.local/share/nvim/lazy/plenary.nvim'),
  vim.fn.expand('~/.local/share/nvim/site/pack/vendor/start/plenary.nvim'),
  vim.fn.expand('~/.local/share/nvim/site/pack/packer/start/plenary.nvim'),
}
for _, p in ipairs(plenary_paths) do
  if vim.fn.isdirectory(p) == 1 then
    vim.cmd('set runtimepath+=' .. p)
    break
  end
end

vim.opt.swapfile = false
vim.opt.backup = false

-- Load the plugin
require('biscuit').setup({
  codes = { 'test_code' },
})
