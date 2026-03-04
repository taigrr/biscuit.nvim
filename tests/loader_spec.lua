local loader = require('biscuit.loader')

describe('biscuit.loader', function()
  describe('get_extensions_for_filetype', function()
    it('should return extensions for known filetypes', function()
      vim.bo.filetype = 'go'
      local exts, err = loader.get_extensions_for_filetype()
      assert.is_nil(err)
      assert.same({ 'go' }, exts)
    end)

    it('should return multiple extensions for typescript', function()
      vim.bo.filetype = 'typescript'
      local exts, err = loader.get_extensions_for_filetype()
      assert.is_nil(err)
      assert.same({ 'ts', 'tsx' }, exts)
    end)

    it('should return filetype as extension for unknown filetypes', function()
      vim.bo.filetype = 'unknownft'
      local exts, err = loader.get_extensions_for_filetype()
      assert.is_nil(err)
      assert.same({ 'unknownft' }, exts)
    end)

    it('should return error for empty filetype', function()
      vim.bo.filetype = ''
      local exts, err = loader.get_extensions_for_filetype()
      assert.is_nil(exts)
      assert.is_not_nil(err)
      assert.is_true(err:find('No filetype') ~= nil)
    end)
  end)

  describe('tracked_buffers', function()
    before_each(function()
      loader.tracked_buffers = {}
    end)

    it('should start with empty tracked buffers', function()
      assert.equals(0, loader.tracked_count())
    end)

    it('should track newly loaded buffers', function()
      local tmpfile = vim.fn.tempname() .. '.lua'
      vim.fn.writefile({ 'return {}' }, tmpfile)

      local bufnr, was_loaded = loader.load_buffer_with_lsp(tmpfile, true)
      assert.is_false(was_loaded)
      assert.is_true(loader.tracked_buffers[bufnr])
      assert.equals(1, loader.tracked_count())

      vim.fn.delete(tmpfile)
      loader.clear_tracked()
    end)

    it('should not track already-loaded buffers', function()
      local tmpfile = vim.fn.tempname() .. '.lua'
      vim.fn.writefile({ 'return {}' }, tmpfile)

      -- Load once
      local bufnr1, was_loaded1 = loader.load_buffer_with_lsp(tmpfile, true)
      assert.is_false(was_loaded1)

      -- Load again
      local bufnr2, was_loaded2 = loader.load_buffer_with_lsp(tmpfile, true)
      assert.is_true(was_loaded2)
      assert.equals(bufnr1, bufnr2)
      assert.equals(1, loader.tracked_count())

      vim.fn.delete(tmpfile)
      loader.clear_tracked()
    end)

    it('should clear all tracked buffers', function()
      local tmpfile1 = vim.fn.tempname() .. '.lua'
      local tmpfile2 = vim.fn.tempname() .. '.lua'
      vim.fn.writefile({ 'return {}' }, tmpfile1)
      vim.fn.writefile({ 'return {}' }, tmpfile2)

      loader.load_buffer_with_lsp(tmpfile1, true)
      loader.load_buffer_with_lsp(tmpfile2, true)
      assert.equals(2, loader.tracked_count())

      local cleared = loader.clear_tracked()
      assert.equals(2, cleared)
      assert.equals(0, loader.tracked_count())

      vim.fn.delete(tmpfile1)
      vim.fn.delete(tmpfile2)
    end)

    it('should unload single tracked buffer', function()
      local tmpfile = vim.fn.tempname() .. '.lua'
      vim.fn.writefile({ 'return {}' }, tmpfile)

      local bufnr = loader.load_buffer_with_lsp(tmpfile, true)
      assert.equals(1, loader.tracked_count())

      local was_unloaded = loader.unload_tracked(bufnr)
      assert.is_true(was_unloaded)
      assert.equals(0, loader.tracked_count())

      vim.fn.delete(tmpfile)
    end)
  end)

  describe('get_root', function()
    it('should return cwd when no LSP is attached', function()
      local root = loader.get_root()
      assert.equals(vim.fn.getcwd(), root)
    end)
  end)
end)
