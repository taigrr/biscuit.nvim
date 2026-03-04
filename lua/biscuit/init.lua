---@class Biscuit
---@field config Biscuit.Config
local M = {}

---@class Biscuit.Config
---@field codes string[] Diagnostic codes to auto-fix (e.g., "any", "slicescontains" from gopls)
---@field batch_size integer Files per batch when loading
---@field batch_delay integer Ms between batches
---@field wave_delay integer Ms to wait between fix waves for LSP to recalculate (default 3000)
---@field max_files integer Max files to load (0 = unlimited)
---@field auto_save boolean Save files after applying actions/formatting
---@field auto_close boolean Close tracked buffers after fixes are applied (default true)
---@field exclude_dirs string[] Directories to exclude from scanning

---@type Biscuit.Config
M.config = {
  codes = {},
  batch_size = 10,
  batch_delay = 50,
  wave_delay = 3000,
  max_files = 0,
  auto_save = true,
  auto_close = true,
  exclude_dirs = { 'node_modules', '.git', 'dist', 'build', '__pycache__', '.venv', 'vendor', '.next', 'coverage' },
}

---@param opts? Biscuit.Config
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)
  require('biscuit.commands').setup()
end

return M
