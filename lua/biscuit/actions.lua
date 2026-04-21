---@class Biscuit.Actions
local M = {}

local loader = require('biscuit.loader')

local function get_config()
  return require('biscuit').config
end

---Check if diagnostic code matches any configured code
---@param diag_code string|number|nil
---@param codes string[]
---@return boolean
local function code_matches(diag_code, codes)
  if diag_code == nil then
    return false
  end
  local code_str = tostring(diag_code)
  for _, c in ipairs(codes) do
    if code_str == c then
      return true
    end
  end
  return false
end

---Get matching diagnostics grouped by buffer
---@param codes string[]
---@return table<integer, table[]> by_buffer
local function get_diagnostics_by_buffer(codes)
  local by_buffer = {}
  for _, diag in ipairs(vim.diagnostic.get()) do
    if code_matches(diag.code, codes) then
      if not by_buffer[diag.bufnr] then
        by_buffer[diag.bufnr] = {}
      end
      table.insert(by_buffer[diag.bufnr], diag)
    end
  end
  return by_buffer
end

---Execute an LSP command via the appropriate client.
---Uses client:exec_command (Neovim 0.11+) with a fallback for older versions.
---@param bufnr integer
---@param command table
local function execute_command(bufnr, command)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    if client.exec_command then
      client:exec_command(command)
      return
    end
  end
  -- Fallback for Neovim < 0.11
  if vim.lsp.buf.execute_command then
    vim.lsp.buf.execute_command(command)
  end
end

---Apply one quickfix action for a diagnostic
---@param bufnr integer
---@param diag table
---@param dry_run boolean
---@param callback fun(applied: boolean, action_title?: string)
local function apply_one_fix(bufnr, diag, dry_run, callback)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    callback(false)
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeAction' })
  if #clients == 0 then
    callback(false)
    return
  end

  local all_diags = {}
  for _, client in ipairs(clients) do
    local ns_push = vim.lsp.diagnostic.get_namespace(client.id, false)
    local ns_pull = vim.lsp.diagnostic.get_namespace(client.id, true)
    vim.list_extend(all_diags, vim.diagnostic.get(bufnr, { namespace = ns_push, lnum = diag.lnum }))
    vim.list_extend(all_diags, vim.diagnostic.get(bufnr, { namespace = ns_pull, lnum = diag.lnum }))
  end

  local matching_diags = vim.tbl_filter(function(d)
    return d.message == diag.message and d.col == diag.col and d.user_data and d.user_data.lsp
  end, all_diags)

  if #matching_diags == 0 then
    callback(false)
    return
  end

  local lsp_diag = matching_diags[1].user_data.lsp
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = {
      start = { line = diag.lnum, character = diag.col },
      ['end'] = { line = diag.lnum, character = diag.col },
    },
    context = {
      diagnostics = { lsp_diag },
      triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
    },
  }

  vim.lsp.buf_request_all(bufnr, 'textDocument/codeAction', params, function(results)
    local actions = {}
    for _, res in pairs(results or {}) do
      for _, action in ipairs(res.result or {}) do
        table.insert(actions, action)
      end
    end

    local quickfix_actions = vim.tbl_filter(function(a)
      return a.kind and (a.kind == 'quickfix' or vim.startswith(a.kind, 'quickfix.'))
    end, actions)

    if #quickfix_actions >= 1 then
      local action = quickfix_actions[1]
      if dry_run then
        callback(true, action.title)
      else
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, 'utf-8')
        end
        if action.command then
          local command = action.command
          if type(command) == 'table' then
            execute_command(bufnr, command)
          end
        end
        callback(true, action.title)
      end
    else
      callback(false)
    end
  end)
end

---Apply quickfix code actions for diagnostics matching configured sources.
---
---Why wave-based batching?
---  LSP servers like gopls can take 3+ seconds to recalculate diagnostics after
---  a file is modified, especially with many open buffers. A naive serial approach
---  (fix one diagnostic, wait for LSP, repeat) is extremely slow.
---
---  Instead, we process in "waves":
---    1. Apply one fix per file in parallel (all files at once)
---    2. Wait wave_delay for LSP to recalculate across all buffers
---    3. Check which buffers still have matching diagnostics
---    4. Repeat until no diagnostics remain
---
---  This turns N*3s into ~W*3s where W is the max diagnostics per file.
---
---Why clean up at the START of the next wave?
---  After applying a fix and saving, the diagnostic disappears immediately from
---  vim.diagnostic.get() (the old diagnostic is cleared). But the LSP hasn't
---  recalculated yet - new diagnostics for that file won't appear until after
---  wave_delay. If we check "does this buffer have diagnostics?" right after
---  fixing, we see zero and incorrectly close the buffer.
---
---  By waiting until the next wave (after wave_delay), the LSP has had time to
---  send fresh diagnostics. Only then can we accurately determine which buffers
---  are truly done.
---
---@param opts? { codes?: string[], dry_run?: boolean }
function M.apply_actions(opts)
  opts = opts or {}
  local cfg = get_config()
  local codes = opts.codes or cfg.codes or {}
  local dry_run = opts.dry_run or false

  if #codes == 0 then
    vim.notify('[biscuit] No codes configured. Use setup({ codes = { "any", "slicescontains" } })', vim.log.levels.WARN)
    return
  end

  local notify = loader.create_notifier('ApplyFixes')
  notify(string.format('Looking for diagnostics with codes: %s', table.concat(codes, ', ')))

  local total_applied = 0
  local total_skipped = 0
  local buffers_cleaned = 0
  local wave = 0
  local max_waves = 100
  local prev_wave_buffers = {}

  local function run_wave()
    wave = wave + 1
    if wave > max_waves then
      notify('Max waves reached', 'warn')
      return
    end

    if cfg.auto_close and next(prev_wave_buffers) then
      local current_by_buffer = get_diagnostics_by_buffer(codes)
      for bufnr_check in pairs(prev_wave_buffers) do
        if not current_by_buffer[bufnr_check] then
          if loader.unload_tracked(bufnr_check) then
            buffers_cleaned = buffers_cleaned + 1
          end
        end
      end
      prev_wave_buffers = {}
    end

    local by_buffer = get_diagnostics_by_buffer(codes)
    local buffers_with_diags = vim.tbl_keys(by_buffer)

    if #buffers_with_diags == 0 then
      local clean_msg = buffers_cleaned > 0 and string.format(', closed %d buffers', buffers_cleaned) or ''
      if dry_run then
        notify(string.format('[DRY RUN] Would apply %d fixes in %d waves%s', total_applied, wave - 1, clean_msg))
      else
        notify(string.format('Applied %d fixes in %d waves%s', total_applied, wave - 1, clean_msg))
      end
      return
    end

    notify(string.format('[Wave %d] Processing %d files...', wave, #buffers_with_diags))

    local pending = #buffers_with_diags
    local wave_applied = 0
    local wave_skipped = 0

    for bufnr, diags in pairs(by_buffer) do
      local diag = diags[1]
      prev_wave_buffers[bufnr] = true

      apply_one_fix(bufnr, diag, dry_run, function(applied, title)
        if applied then
          wave_applied = wave_applied + 1
          total_applied = total_applied + 1
          if dry_run then
            local fname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':~:.')
            vim.notify(
              string.format('[DRY RUN] %s:%d [%s] %s', fname, diag.lnum + 1, diag.code or '?', title),
              vim.log.levels.INFO
            )
          elseif cfg.auto_save and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modified then
            vim.api.nvim_buf_call(bufnr, function()
              vim.cmd('silent! write')
            end)
          end
        else
          wave_skipped = wave_skipped + 1
          total_skipped = total_skipped + 1
        end

        pending = pending - 1
        if pending == 0 then
          if wave_applied == 0 then
            local clean_msg = buffers_cleaned > 0 and string.format(', closed %d buffers', buffers_cleaned) or ''
            notify(string.format('Done. Applied %d, skipped %d%s', total_applied, total_skipped, clean_msg))
          else
            vim.defer_fn(run_wave, cfg.wave_delay)
          end
        end
      end)
    end
  end

  run_wave()
end

---List available diagnostic codes
---@param opts? { limit?: integer }
function M.list_codes(opts)
  opts = opts or {}
  local limit = opts.limit or 100

  local diagnostics = vim.diagnostic.get()
  if #diagnostics == 0 then
    vim.notify('No diagnostics found', vim.log.levels.INFO)
    return
  end

  local by_code = {}
  for _, diag in ipairs(diagnostics) do
    local code = diag.code and tostring(diag.code) or nil
    if code then
      if not by_code[code] then
        by_code[code] = { count = 0, sources = {} }
      end
      by_code[code].count = by_code[code].count + 1
      if diag.source then
        by_code[code].sources[diag.source] = true
      end
    end
  end

  local sorted = {}
  for code, data in pairs(by_code) do
    table.insert(sorted, { code = code, count = data.count, sources = data.sources })
  end
  table.sort(sorted, function(a, b)
    return a.count > b.count
  end)

  if #sorted == 0 then
    vim.notify('No diagnostic codes found (diagnostics have no code field)', vim.log.levels.INFO)
    return
  end

  vim.notify('Diagnostic codes (for biscuit config):', vim.log.levels.INFO)
  local shown = 0
  for _, item in ipairs(sorted) do
    if shown >= limit then
      break
    end
    shown = shown + 1
    local source_list = vim.tbl_keys(item.sources)
    local sources_str = #source_list > 0 and (' from ' .. table.concat(source_list, ', ')) or ''
    vim.notify(string.format('  [%d] %s%s', item.count, item.code, sources_str), vim.log.levels.INFO)
  end
end

return M
