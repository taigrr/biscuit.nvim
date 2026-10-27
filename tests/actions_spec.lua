local actions = require('biscuit.actions')

describe('biscuit.actions', function()
  before_each(function()
    require('biscuit').setup({ codes = { 'test_code' } })
  end)

  describe('code_matches (internal)', function()
    -- We can't directly test private functions, but we can test behavior
    -- through the public interface
  end)

  describe('apply_actions', function()
    it('should warn when no codes configured', function()
      require('biscuit').setup({ codes = {} })

      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if msg:find('No codes configured') then
          notified = true
        end
      end

      actions.apply_actions({})

      vim.notify = original_notify
      assert.is_true(notified)
    end)

    it('should accept codes from opts', function()
      require('biscuit').setup({ codes = {} })

      local notified_codes = nil
      local original_notify = vim.notify
      vim.notify = function(msg)
        local match = msg:match('codes: (.+)')
        if match then
          notified_codes = match
        end
      end

      actions.apply_actions({ codes = { 'any', 'slicescontains' } })

      vim.notify = original_notify
      assert.is_not_nil(notified_codes)
      assert.is_true(notified_codes:find('any') ~= nil)
    end)

    it('should skip disabled quickfixes in apply and dry-run modes', function()
      local bufnr = vim.api.nvim_create_buf(true, false)
      local originals = {
        diagnostic_get = vim.diagnostic.get,
        get_clients = vim.lsp.get_clients,
        get_namespace = vim.lsp.diagnostic.get_namespace,
        buf_request_all = vim.lsp.buf_request_all,
        apply_workspace_edit = vim.lsp.util.apply_workspace_edit,
        defer_fn = vim.defer_fn,
        notify = vim.notify,
      }
      local applied_edits = {}
      local notifications = {}
      local results = {}
      local diagnostic = {
        bufnr = bufnr, lnum = 0, col = 0, code = 'test_code', message = 'fix me',
        user_data = { lsp = { code = 'test_code', message = 'fix me' } },
      }
      vim.diagnostic.get = function() return { diagnostic } end
      vim.lsp.get_clients = function() return { { id = 1 } } end
      vim.lsp.diagnostic.get_namespace = function() return 1 end
      vim.lsp.buf_request_all = function(_, _, _, callback)
        callback({ [1] = { result = results } })
      end
      vim.lsp.util.apply_workspace_edit = function(edit)
        table.insert(applied_edits, edit)
      end
      vim.defer_fn = function() end
      vim.notify = function(message) table.insert(notifications, message) end

      local ok, err = pcall(function()
        local disabled = {
          title = 'Unavailable fix', kind = 'quickfix',
          disabled = { reason = 'Not applicable' }, edit = {},
        }
        local enabled = { title = 'Available fix', kind = 'quickfix.test', edit = {} }
        for _, dry_run in ipairs({ false, true }) do
          results = { disabled }
          notifications = {}
          actions.apply_actions({ dry_run = dry_run })
          assert.same({}, applied_edits)
          assert.is_truthy(notifications[#notifications]:find('Applied 0, skipped 1', 1, true))

          results = { disabled, enabled }
          actions.apply_actions({ dry_run = dry_run })
          if dry_run then
            assert.is_truthy(table.concat(notifications, '\n'):find('Available fix', 1, true))
          else
            assert.same({ enabled.edit }, applied_edits)
          end
          applied_edits = {}
        end
      end)

      vim.diagnostic.get = originals.diagnostic_get
      vim.lsp.get_clients = originals.get_clients
      vim.lsp.diagnostic.get_namespace = originals.get_namespace
      vim.lsp.buf_request_all = originals.buf_request_all
      vim.lsp.util.apply_workspace_edit = originals.apply_workspace_edit
      vim.defer_fn = originals.defer_fn
      vim.notify = originals.notify
      vim.api.nvim_buf_delete(bufnr, { force = true })
      assert.is_true(ok, err)
    end)

    it('should request only quickfix code actions', function()
      local bufnr = vim.api.nvim_create_buf(true, false)
      local captured_params = nil

      local original_diagnostic_get = vim.diagnostic.get
      local original_get_clients = vim.lsp.get_clients
      local original_get_namespace = vim.lsp.diagnostic.get_namespace
      local original_buf_request_all = vim.lsp.buf_request_all
      local original_notify = vim.notify

      vim.diagnostic.get = function(candidate)
        if candidate == bufnr then
          return {
            {
              lnum = 0,
              col = 0,
              message = 'replace interface{}',
              user_data = { lsp = { code = 'test_code', message = 'replace interface{}' } },
            },
          }
        end
        return {
          {
            bufnr = bufnr,
            lnum = 0,
            col = 0,
            code = 'test_code',
            message = 'replace interface{}',
          },
        }
      end

      vim.lsp.get_clients = function(opts)
        if opts and opts.bufnr == bufnr then
          return { { id = 1 } }
        end
        return {}
      end

      vim.lsp.diagnostic.get_namespace = function()
        return 1
      end

      vim.lsp.buf_request_all = function(candidate, method, params, callback)
        if candidate == bufnr and method == 'textDocument/codeAction' then
          captured_params = params
        end
        callback({ [1] = { result = {} } })
      end

      vim.notify = function() end

      local ok, err = pcall(function()
        actions.apply_actions({ codes = { 'test_code' } })
      end)

      vim.diagnostic.get = original_diagnostic_get
      vim.lsp.get_clients = original_get_clients
      vim.lsp.diagnostic.get_namespace = original_get_namespace
      vim.lsp.buf_request_all = original_buf_request_all
      vim.notify = original_notify

      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end

      assert.is_true(ok, err)
      assert.same({ 'quickfix' }, captured_params.context.only)
    end)
  end)

  describe('list_codes', function()
    it('should notify when no diagnostics found', function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg)
        if msg:find('No diagnostics found') then
          notified = true
        end
      end

      actions.list_codes()

      vim.notify = original_notify
      assert.is_true(notified)
    end)
  end)
end)
