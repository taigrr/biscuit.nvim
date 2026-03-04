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
