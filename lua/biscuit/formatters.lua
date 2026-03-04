---@class Biscuit.Formatters
local M = {}

local loader = require('biscuit.loader')

local function get_config()
  return require('biscuit').config
end

---Format all loaded buffers using LSP
---@param opts? { dry_run?: boolean }
function M.format_buffers(opts)
  opts = opts or {}
  local cfg = get_config()
  local dry_run = opts.dry_run or false

  local notify = loader.create_notifier('FormatBuffers')

  -- Get all loaded buffers with LSP clients that support formatting
  local buffers_to_format = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buflisted then
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      for _, client in ipairs(clients) do
        if client.supports_method('textDocument/formatting') then
          table.insert(buffers_to_format, bufnr)
          break
        end
      end
    end
  end

  if #buffers_to_format == 0 then
    notify('No buffers with LSP formatting support', 'warn')
    return
  end

  notify(string.format('Formatting %d buffers...', #buffers_to_format))

  local formatted = 0
  local failed = 0
  local idx = 0

  local function format_next()
    idx = idx + 1
    if idx > #buffers_to_format then
      if dry_run then
        notify(string.format('[DRY RUN] Would format %d buffers', formatted))
      else
        notify(string.format('Formatted %d buffers, %d failed', formatted, failed))
      end
      return
    end

    local bufnr = buffers_to_format[idx]
    local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.')

    if dry_run then
      vim.notify(string.format('[DRY RUN] %s', fname), vim.log.levels.INFO)
      formatted = formatted + 1
      vim.defer_fn(format_next, 1)
      return
    end

    vim.lsp.buf_request(bufnr, 'textDocument/formatting', {
      textDocument = vim.lsp.util.make_text_document_params(bufnr),
      options = {
        tabSize = vim.bo[bufnr].shiftwidth,
        insertSpaces = vim.bo[bufnr].expandtab,
      },
    }, function(err, result)
      if err then
        failed = failed + 1
        vim.notify(string.format('[biscuit] %s: %s', fname, err.message or 'format failed'), vim.log.levels.WARN)
      elseif result then
        vim.lsp.util.apply_text_edits(result, bufnr, 'utf-8')
        formatted = formatted + 1

        -- Auto-save if configured
        if cfg.auto_save and vim.bo[bufnr].modified then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd('silent! write')
          end)
        end
      else
        formatted = formatted + 1
      end

      if idx % 20 == 0 then
        notify(string.format('[%d/%d] Formatting...', idx, #buffers_to_format))
      end

      vim.defer_fn(format_next, 10)
    end)
  end

  format_next()
end

return M
