local biscuit = require('biscuit')

describe('biscuit', function()
  describe('setup', function()
    it('should initialize with default config', function()
      biscuit.setup({})
      assert.is_table(biscuit.config)
      assert.is_table(biscuit.config.codes)
      assert.equals(10, biscuit.config.batch_size)
      assert.equals(50, biscuit.config.batch_delay)
      assert.equals(3000, biscuit.config.wave_delay)
      assert.equals(0, biscuit.config.max_files)
      assert.is_true(biscuit.config.auto_save)
      assert.is_true(biscuit.config.auto_close)
    end)

    it('should merge user config with defaults', function()
      biscuit.setup({
        codes = { 'any', 'slicescontains' },
        batch_size = 20,
        auto_save = false,
      })
      assert.same({ 'any', 'slicescontains' }, biscuit.config.codes)
      assert.equals(20, biscuit.config.batch_size)
      assert.is_false(biscuit.config.auto_save)
      -- Defaults preserved
      assert.equals(50, biscuit.config.batch_delay)
      assert.equals(3000, biscuit.config.wave_delay)
    end)

    it('should preserve exclude_dirs defaults when not overridden', function()
      biscuit.setup({})
      assert.is_table(biscuit.config.exclude_dirs)
      assert.is_true(vim.tbl_contains(biscuit.config.exclude_dirs, 'node_modules'))
      assert.is_true(vim.tbl_contains(biscuit.config.exclude_dirs, '.git'))
      assert.is_true(vim.tbl_contains(biscuit.config.exclude_dirs, 'vendor'))
    end)
  end)

  describe('commands', function()
    before_each(function()
      biscuit.setup({ codes = { 'test_code' } })
    end)

    it('should register LoadLSP command', function()
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.LoadLSP)
    end)

    it('should register ApplyFixes command', function()
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.ApplyFixes)
    end)

    it('should register ListDiagnosticCodes command', function()
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.ListDiagnosticCodes)
    end)

    it('should register ListConfiguredCodes command', function()
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.ListConfiguredCodes)
    end)

    it('should register FormatBuffers command', function()
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.FormatBuffers)
    end)

    it('should register UnloadHidden command', function()
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.UnloadHidden)
    end)

    it('should register UnloadTracked command', function()
      local cmds = vim.api.nvim_get_commands({})
      assert.is_not_nil(cmds.UnloadTracked)
    end)
  end)
end)
