---@class Biscuit.Loader
local M = {}

---@type table<integer, boolean>
M.tracked_buffers = {}

local config = function()
  return require('biscuit').config
end

local ft_to_ext = {
  typescript = { 'ts', 'tsx' },
  typescriptreact = { 'ts', 'tsx' },
  javascript = { 'js', 'jsx' },
  javascriptreact = { 'js', 'jsx' },
  lua = { 'lua' },
  go = { 'go' },
  python = { 'py' },
  rust = { 'rs' },
  c = { 'c', 'h' },
  cpp = { 'cpp', 'hpp', 'cc', 'hh', 'cxx', 'hxx' },
  zig = { 'zig' },
  vue = { 'vue' },
  svelte = { 'svelte' },
  ruby = { 'rb' },
  php = { 'php' },
  java = { 'java' },
  kotlin = { 'kt', 'kts' },
  swift = { 'swift' },
  cs = { 'cs' },
  css = { 'css' },
  scss = { 'scss' },
  html = { 'html', 'htm' },
  json = { 'json' },
  yaml = { 'yaml', 'yml' },
  toml = { 'toml' },
  markdown = { 'md' },
}

---Read the current file descriptor soft limit.
---macOS defaults to 256 which is far too low for loading hundreds of buffers.
---@return integer current_limit
local function get_fd_limit()
  local handle = io.popen('ulimit -n 2>/dev/null')
  if not handle then
    return 256
  end
  local result = handle:read('*l')
  handle:close()
  return tonumber(result) or 256
end

---Get file extensions for current buffer's filetype
---@return string[]|nil extensions
---@return string|nil error
function M.get_extensions_for_filetype()
  local ft = vim.bo.filetype
  if ft == '' then
    return nil, 'No filetype detected in current buffer'
  end

  local exts = ft_to_ext[ft]
  if not exts then
    exts = { ft }
  end

  return exts, nil
end

---Get LSP root directory or cwd
---@return string
function M.get_root()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  for _, client in ipairs(clients) do
    if client.root_dir then
      return client.root_dir
    end
  end

  local roots = vim.lsp.buf.list_workspace_folders()
  if #roots > 0 then
    return roots[1]
  end

  return vim.fn.getcwd()
end

---Find files asynchronously using fd or glob
---@param root string
---@param exts string[]
---@param on_done fun(files: string[])
function M.find_files_async(root, exts, on_done)
  local results = {}
  local stdout = vim.uv.new_pipe(false)
  local handle ---@type uv.uv_process_t|nil
  local stdout_closed = false
  local handle_closed = false

  local function safe_close()
    if not stdout_closed and stdout then
      stdout_closed = true
      if not stdout:is_closing() then
        stdout:close()
      end
    end
    if not handle_closed and handle then
      handle_closed = true
      if not handle:is_closing() then
        handle:close()
      end
    end
  end

  local function finish()
    safe_close()
    vim.schedule(function()
      on_done(results)
    end)
  end

  local args = { '--type', 'f', '--hidden', '--no-ignore-vcs' }

  for _, dir in ipairs(config().exclude_dirs) do
    table.insert(args, '--exclude')
    table.insert(args, dir)
  end

  for _, ext in ipairs(exts) do
    table.insert(args, '--extension')
    table.insert(args, ext)
  end
  table.insert(args, '.')

  if vim.fn.executable('fd') == 1 then
    handle = vim.uv.spawn('fd', {
      args = args,
      cwd = root,
      stdio = { nil, stdout, nil },
    }, function()
      finish()
    end)

    if not handle then
      safe_close()
      vim.schedule(function()
        vim.notify('[biscuit] Failed to spawn fd', vim.log.levels.ERROR)
        on_done(results)
      end)
      return
    end

    vim.uv.read_start(stdout, function(err, data)
      if err then
        vim.schedule(function()
          vim.notify('[biscuit] fd error: ' .. err, vim.log.levels.ERROR)
        end)
      elseif data then
        for line in data:gmatch('[^\r\n]+') do
          table.insert(results, vim.fn.fnamemodify(root .. '/' .. line, ':p'))
        end
      end
    end)
  else
    vim.schedule(function()
      for _, ext in ipairs(exts) do
        local matches = vim.fn.globpath(root, '**/*.' .. ext, false, true)
        vim.list_extend(results, matches)
      end
      on_done(results)
    end)
  end
end

---Load buffer and attach LSP (skips already-loaded buffers)
---@param filepath string
---@param track? boolean Whether to track this buffer for later cleanup (default true)
---@return integer bufnr
---@return boolean was_loaded True if buffer was already loaded
function M.load_buffer_with_lsp(filepath, track)
  if track == nil then track = true end
  local bufnr = vim.fn.bufadd(filepath)
  local was_loaded = vim.api.nvim_buf_is_loaded(bufnr)
  if not was_loaded then
    vim.fn.bufload(bufnr)
    if track then
      M.tracked_buffers[bufnr] = true
    end
  end
  return bufnr, was_loaded
end

---Unload a tracked buffer if it was loaded by LoadLSP
---@param bufnr integer
---@return boolean was_unloaded
function M.unload_tracked(bufnr)
  if M.tracked_buffers[bufnr] then
    M.tracked_buffers[bufnr] = nil
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
      return true
    end
  end
  return false
end

---Get count of tracked buffers
---@return integer
function M.tracked_count()
  local count = 0
  for _ in pairs(M.tracked_buffers) do
    count = count + 1
  end
  return count
end

---Clear all tracked buffers (unload them)
---@return integer count Number of buffers unloaded
function M.clear_tracked()
  local count = 0
  for bufnr in pairs(M.tracked_buffers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
      count = count + 1
    end
  end
  M.tracked_buffers = {}
  return count
end

---Create a progress notifier
---@param title string
---@return fun(text: string, level?: string)
function M.create_notifier(title)
  local has_noice, noice = pcall(require, 'noice')
  local msg_id = nil

  return function(text, level)
    level = level or 'info'
    if has_noice then
      msg_id = noice.notify(text, level, { title = title, replace = msg_id })
    else
      vim.notify(text, level == 'error' and vim.log.levels.ERROR or vim.log.levels.INFO)
    end
  end
end

---Load files into LSP for diagnostics.
---
---Buffers are loaded in small batches with delays between them to avoid
---hitting the macOS default file descriptor limit (EMFILE "too many open
---files"). The batch_size and batch_delay config options control throughput
---vs. fd pressure.
---@param opts? { folder?: string, extensions?: string[] }
function M.load_files(opts)
  opts = opts or {}
  local folder = opts.folder
  local exts = opts.extensions

  if not exts then
    local detected, err = M.get_extensions_for_filetype()
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end
    exts = detected
  end

  local root = folder or M.get_root()
  local notify = M.create_notifier('LoadLSP')
  local cfg = config()

  -- Try to raise fd limit before loading hundreds of files
  local fd_limit = get_fd_limit()
  if fd_limit < 1024 then
    notify(string.format('Warning: low fd limit (%d). Consider running `ulimit -n 4096` before Neovim.', fd_limit), 'warn')
  end

  ---@cast exts string[]
  notify(string.format('Scanning %s for %s files...', root, table.concat(exts, ', ')))

  M.find_files_async(root, exts, function(files)
    if cfg.max_files > 0 and #files > cfg.max_files then
      files = vim.list_slice(files, 1, cfg.max_files)
    end

    local total = #files
    if total == 0 then
      notify('No matching files found', 'warn')
      return
    end

    -- If the total exceeds a safe threshold relative to the fd limit,
    -- automatically cap batch_size to avoid EMFILE.
    -- Each loaded buffer holds ~1-2 fds (file + LSP pipe). Reserve 128 fds
    -- for Neovim internals, LSP processes, and other I/O.
    local safe_concurrent = math.max(1, fd_limit - 128)
    local effective_batch = math.min(cfg.batch_size, safe_concurrent)

    local loaded = 0
    local skipped = 0

    local function load_batch(start_idx)
      local end_idx = math.min(start_idx + effective_batch - 1, total)

      for i = start_idx, end_idx do
        local _, was_loaded = M.load_buffer_with_lsp(files[i])
        if was_loaded then
          skipped = skipped + 1
        else
          loaded = loaded + 1
        end
      end

      local processed = loaded + skipped
      if processed % 50 == 0 or processed == total then
        notify(string.format('[%d/%d] Loading...', processed, total))
      end

      if end_idx < total then
        vim.defer_fn(function()
          load_batch(end_idx + 1)
        end, cfg.batch_delay)
      else
        vim.defer_fn(function()
          local diag_count = #vim.diagnostic.get()
          local skip_msg = skipped > 0 and string.format(' (%d already loaded)', skipped) or ''
          notify(string.format('Loaded %d files%s. %d diagnostics found.', loaded, skip_msg, diag_count))
        end, 500)
      end
    end

    load_batch(1)
  end)
end

---Unload all hidden buffers
function M.unload_hidden()
  local count = 0
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.fn.buflisted(bufnr) == 1 then
      local wins = vim.fn.win_findbuf(bufnr)
      if #wins == 0 then
        vim.api.nvim_buf_delete(bufnr, { force = true })
        count = count + 1
      end
    end
  end
  vim.notify(string.format('Unloaded %d hidden buffers', count), vim.log.levels.INFO)
end

return M
