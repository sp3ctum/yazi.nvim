local assert = require('luassert')
local event_handling = require('yazi.event_handling')

describe('process_trash_event', function()
  before_each(function()
    -- clear all buffers
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)

  it('deletes a buffer that matches the trash event exactly', function()
    local buffer = vim.fn.bufadd('/abc/def')

    ---@type YaziTrashEvent
    local event = {
      type = 'trash',
      timestamp = '1712766606832135',
      id = '1712766606832135',
      data = { urls = { '/abc/def' } },
    }

    event_handling.process_delete_event(event)

    assert.is_false(vim.api.nvim_buf_is_valid(buffer))
  end)

  it('deletes a buffer that matches the parent directory', function()
    local buffer = vim.fn.bufadd('/abc/def')

    ---@type YaziTrashEvent
    local event = {
      type = 'trash',
      timestamp = '1712766606832135',
      id = '1712766606832135',
      data = { urls = { '/abc' } },
    }

    event_handling.process_delete_event(event)

    assert.is_false(vim.api.nvim_buf_is_valid(buffer))
  end)

  it("doesn't delete a buffer that doesn't match the trash event", function()
    local buffer = vim.fn.bufadd('/abc/def')

    ---@type YaziTrashEvent
    local event = {
      type = 'trash',
      timestamp = '1712766606832135',
      id = '1712766606832135',
      data = { urls = { '/abc/ghi' } },
    }

    event_handling.process_delete_event(event)

    assert.is_true(vim.api.nvim_buf_is_valid(buffer))
  end)
end)
