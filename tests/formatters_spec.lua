local formatters = require('biscuit.formatters')

describe('biscuit.formatters', function()
  before_each(function()
    require('biscuit').setup({ auto_save = false })
  end)

  it('should only request formatting once per buffer even with multiple formatting clients', function()
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.bo[bufnr].buflisted = true

    local original_list_bufs = vim.api.nvim_list_bufs
    local original_buf_is_loaded = vim.api.nvim_buf_is_loaded
    local original_get_clients = vim.lsp.get_clients
    local original_buf_request = vim.lsp.buf_request
    local original_defer_fn = vim.defer_fn
    local original_notify = vim.notify

    local requests = 0

    vim.api.nvim_list_bufs = function()
      return { bufnr }
    end

    vim.api.nvim_buf_is_loaded = function(candidate)
      return candidate == bufnr
    end

    vim.lsp.get_clients = function(opts)
      if opts and opts.bufnr == bufnr then
        return {
          { supports_method = function(method) return method == 'textDocument/formatting' end },
          { supports_method = function(method) return method == 'textDocument/formatting' end },
        }
      end
      return {}
    end

    vim.lsp.buf_request = function(candidate, method, params, callback)
      requests = requests + 1
      callback(nil, nil)
      return 1
    end

    vim.defer_fn = function(callback)
      callback()
    end

    vim.notify = function() end

    local ok, err = pcall(function()
      formatters.format_buffers()
    end)

    vim.api.nvim_list_bufs = original_list_bufs
    vim.api.nvim_buf_is_loaded = original_buf_is_loaded
    vim.lsp.get_clients = original_get_clients
    vim.lsp.buf_request = original_buf_request
    vim.defer_fn = original_defer_fn
    vim.notify = original_notify

    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    assert.is_true(ok, err)
    assert.equals(1, requests)
  end)
end)
