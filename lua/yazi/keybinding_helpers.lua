---@module "plenary.path"

local openers = require('yazi.openers')
local Log = require('yazi.log')
local utils = require('yazi.utils')

--- Hacky actions that can be used when yazi is open. They typically select the
--- current file and execute some useful operation on the selected file.
local YaziOpenerActions = {}

---@param config YaziConfig
function YaziOpenerActions.open_file_in_vertical_split(config)
  YaziOpenerActions.select_current_file_and_close_yazi(config, {
    on_file_opened = openers.open_file_in_vertical_split,
  })
end

---@param config YaziConfig
function YaziOpenerActions.open_file_in_horizontal_split(config)
  YaziOpenerActions.select_current_file_and_close_yazi(config, {
    on_file_opened = openers.open_file_in_horizontal_split,
  })
end

---@param config YaziConfig
function YaziOpenerActions.open_file_in_tab(config)
  YaziOpenerActions.select_current_file_and_close_yazi(config, {
    on_file_opened = openers.open_file_in_tab,
  })
end

--
--
--
--
---@class (exact) YaziOpenerActionsCallbacks
---@field on_file_opened fun(chosen_file: string, config: YaziConfig, state: YaziClosedState):nil
---@field on_multiple_files_opened? fun(chosen_files: string[], config: YaziConfig, state: YaziClosedState):nil

-- This is a utility function that can be used in the set_keymappings_function
-- You can also use it in your own keymappings function
---@param config YaziConfig
---@param callbacks YaziOpenerActionsCallbacks
function YaziOpenerActions.select_current_file_and_close_yazi(config, callbacks)
  config.open_file_function = callbacks.on_file_opened

  if callbacks.on_multiple_files_opened == nil then
    callbacks.on_multiple_files_opened = function(chosen_files, cfg, state)
      for _, chosen_file in ipairs(chosen_files) do
        cfg.open_file_function(chosen_file, cfg, state)
      end
    end
  end

  config.hooks.yazi_opened_multiple_files = callbacks.on_multiple_files_opened

  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes('<enter>', true, false, true),
    'n',
    true
  )
end

---@param context YaziActiveContext
function YaziOpenerActions.cycle_open_buffers(context)
  assert(context.input_path, 'No input path found')
  assert(context.input_path.filename, 'No input path filename found')

  local current_cycle_position = (
    context.cycled_file and context.cycled_file.path
  ) or context.input_path
  local visible_buffers = utils.get_visible_open_buffers()

  if #visible_buffers == 0 then
    Log:debug(
      string.format(
        'No visible buffers found for path: "%s"',
        context.input_path
      )
    )
    return
  end

  for i, buffer in ipairs(visible_buffers) do
    if
      buffer.renameable_buffer:matches_exactly(current_cycle_position.filename)
    then
      Log:debug(
        string.format(
          'Found buffer for path: "%s", will open the next buffer',
          context.input_path
        )
      )
      local other_buffers = vim.list_slice(visible_buffers, i + 1)
      other_buffers = vim.list_extend(other_buffers, visible_buffers, 1, i - 1)
      local next_buffer = vim.iter(other_buffers):find(function(b)
        return b.renameable_buffer.path.filename
          ~= current_cycle_position.filename
      end)
      assert(
        next_buffer,
        vim.inspect({
          'Could not find next buffer',
          #visible_buffers,
          i,
          next,
        })
      )

      local directory =
        vim.fn.fnamemodify(next_buffer.renameable_buffer.path.filename, ':h')
      assert(
        directory,
        string.format(
          'Found the next buffer, but could not find its base directory. The buffer: "%s", aborting.',
          next_buffer.renameable_buffer.path.filename
        )
      )

      context.api:cd(directory)
      context.cycled_file = next_buffer.renameable_buffer
      return
    end
  end

  Log:debug(
    string.format(
      'Could not find cycle_open_buffers for path: "%s"',
      context.input_path
    )
  )
end

return YaziOpenerActions
