local M = {}

function M.check()
  vim.health.start('biscuit.nvim')

  -- Check Neovim version
  local nvim_version = vim.version()
  if nvim_version.major > 0 or (nvim_version.major == 0 and nvim_version.minor >= 10) then
    vim.health.ok(string.format('Neovim version: %d.%d.%d', nvim_version.major, nvim_version.minor, nvim_version.patch))
  else
    vim.health.error('Neovim >= 0.10.0 required', 'Update Neovim to a newer version')
  end

  -- Check for fd (optional but recommended)
  if vim.fn.executable('fd') == 1 then
    vim.health.ok('fd found (fast file search)')
  else
    vim.health.warn('fd not found', 'Install fd for faster file discovery: https://github.com/sharkdp/fd')
  end

  -- Check LSP
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients > 0 then
    local names = vim.tbl_map(function(c)
      return c.name
    end, clients)
    vim.health.ok('LSP clients active: ' .. table.concat(names, ', '))
  else
    vim.health.info('No LSP clients attached to current buffer')
  end

  -- Check configuration
  local ok, biscuit = pcall(require, 'biscuit')
  if ok then
    local cfg = biscuit.config
    vim.health.ok(string.format('Diagnostic codes configured: %d', #cfg.codes))
    if #cfg.codes > 0 then
      vim.health.info('  ' .. table.concat(cfg.codes, ', '))
    end
    vim.health.info(string.format('Wave delay: %dms', cfg.wave_delay))
    vim.health.info(string.format('Auto-close tracked buffers: %s', cfg.auto_close and 'yes' or 'no'))

    local loader = require('biscuit.loader')
    local tracked = loader.tracked_count()
    if tracked > 0 then
      vim.health.info(string.format('Tracked buffers: %d', tracked))
    end
  else
    vim.health.warn('biscuit not loaded - call setup() first')
  end
end

return M
