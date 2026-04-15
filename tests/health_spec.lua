local health = require('biscuit.health')

describe('biscuit.health', function()
  before_each(function()
    require('biscuit').setup({ codes = { 'any', 'slicescontains' } })
  end)

  it('should run check without errors', function()
    -- health.check() calls vim.health.start/ok/info/warn/error
    -- just verify it doesn't throw
    assert.has_no.errors(function()
      health.check()
    end)
  end)
end)
