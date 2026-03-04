-- Minimal init for testing
vim.cmd([[set runtimepath+=.]])
vim.cmd([[set runtimepath+=~/.local/share/nvim/site/pack/vendor/start/plenary.nvim]])

vim.opt.swapfile = false
vim.opt.backup = false

-- Load the plugin
require('biscuit').setup({
  codes = { 'test_code' },
})
