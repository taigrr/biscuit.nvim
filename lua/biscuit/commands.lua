---@class Biscuit.Commands
local M = {}

function M.setup()
  local loader = require("biscuit.loader")
  local actions = require("biscuit.actions")
  local formatters = require("biscuit.formatters")
  local plugin = require("biscuit")

  -- Load files into LSP
  vim.api.nvim_create_user_command("LoadLSP", function(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local folder, exts

    if #args > 0 then
      if vim.fn.isdirectory(args[1]) == 1 then
        folder = vim.fn.expand(args[1])
        if #args > 1 then
          exts = vim.list_slice(args, 2)
        end
      else
        exts = args
      end
    end

    loader.load_files({ folder = folder, extensions = exts })
  end, {
    nargs = "*",
    complete = function(_, line)
      local words = vim.split(line, "%s+")
      if #words <= 2 then
        return vim.fn.getcompletion(words[#words] or "", "dir")
      end
      return {}
    end,
    desc = "Load files into LSP for project-wide diagnostics",
  })

  -- Unload hidden buffers
  vim.api.nvim_create_user_command("UnloadHidden", function()
    loader.unload_hidden()
  end, {
    desc = "Unload all hidden buffers to free LSP resources",
  })

  -- Unload buffers loaded by LoadLSP
  vim.api.nvim_create_user_command("UnloadTracked", function()
    local count = loader.clear_tracked()
    vim.notify(string.format("[biscuit] Unloaded %d tracked buffers", count), vim.log.levels.INFO)
  end, {
    desc = "Unload buffers that were loaded by :LoadLSP",
  })

  -- Apply code actions by diagnostic code
  vim.api.nvim_create_user_command("ApplyFixes", function(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local codes = #args > 0 and args or nil
    actions.apply_actions({ codes = codes, dry_run = opts.bang })
  end, {
    nargs = "*",
    bang = true,
    desc = 'Apply quickfix actions for diagnostic codes (e.g., "any", "slicescontains"). Use ! for dry run.',
  })

  -- List diagnostic codes
  vim.api.nvim_create_user_command("ListDiagnosticCodes", function()
    actions.list_codes()
  end, {
    desc = "List diagnostic codes from loaded buffers",
  })

  -- List configured codes
  vim.api.nvim_create_user_command("ListConfiguredCodes", function()
    local cfg = plugin.config
    if #cfg.codes == 0 then
      vim.notify("[biscuit] No codes configured", vim.log.levels.INFO)
      return
    end
    vim.notify("Configured diagnostic codes:", vim.log.levels.INFO)
    for _, code in ipairs(cfg.codes) do
      vim.notify("  " .. code, vim.log.levels.INFO)
    end
  end, {
    desc = "List configured diagnostic codes",
  })

  -- Format all loaded buffers using LSP
  vim.api.nvim_create_user_command("FormatBuffers", function(opts)
    formatters.format_buffers({ dry_run = opts.bang })
  end, {
    bang = true,
    desc = "Format all loaded buffers using LSP. Use ! for dry run.",
  })
end

return M
