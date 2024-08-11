local stub = require("luassert.stub")
local assert = require("luassert")
local yazi = require("yazi")

local function assert_buffer_contains_text(needle)
  local buffer_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(buffer_text, "\n")
  local message = string.format(
    "Expected the main string to contain the substring.\nMain string: '%s'\nSubstring: '%s'",
    text,
    needle
  )

  local found = string.find(text, needle, 1, true) ~= nil
  assert(found, message)
end

local function assert_buffer_does_not_contain_text(needle)
  local buffer_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(buffer_text, "\n")
  local message = string.format(
    "Expected the main string to not contain the substring.\nMain string: '%s'\nSubstring: '%s'",
    text,
    needle
  )

  local found = string.find(text, needle, 1, true) ~= nil
  assert.is_false(found, message)
end

-- make nvim find the health check file so that it can be executed by :checkhealth
-- without this, the health check will not be found
vim.opt.rtp:append(".")

local mock_app_versions = {}

describe("the healthcheck", function()
  local snapshot

  before_each(function()
    snapshot = assert:snapshot()
    mock_app_versions = {
      ["yazi"] = "yazi 0.2.5 (f5a7ace 2024-06-23)",
      ["yazi --help"] = [[Usage: yazi [OPTIONS] [ENTRY]

Arguments:
  [ENTRY]  Set the current working entry

Options:
      --cwd-file <CWD_FILE>            Write the cwd on exit to this file
      --chooser-file <CHOOSER_FILE>    Write the selected files to this file on open fired
      --clear-cache                    Clear the cache directory
      --client-id <CLIENT_ID>          Use the specified client ID, must be a globally unique number
      --local-events <LOCAL_EVENTS>    Report the specified local events to stdout
      --remote-events <REMOTE_EVENTS>  Report the specified remote events to stdout
      --debug                          Print debug information
  -V, --version                        Print version
  -h, --help                           Print help
      ]],
      ["ya"] = "Ya 0.2.5 (f5a7ace 2024-06-23)",
      ["nvim-0.10.0"] = true,
    }

    stub(vim.fn, "has", function(needle)
      if mock_app_versions[needle] then
        return 1
      else
        return 0
      end
    end)

    stub(vim.fn, "executable", function(command)
      return mock_app_versions[command] and 1 or 0
    end)

    stub(vim.fn, "system", function(command)
      if command == "yazi --version" then
        return mock_app_versions["yazi"]
      elseif command == "ya --version" then
        return mock_app_versions["ya"]
      elseif command == "yazi --help" then
        return mock_app_versions["yazi --help"]
      else
        error("the command is not mocked in the test: " .. vim.inspect(command))
      end
    end)
  end)

  after_each(function()
    snapshot:revert()
  end)

  it("reports everything is ok", function()
    yazi.setup({ use_ya_for_events_reading = true })
    vim.cmd("checkhealth yazi")

    assert_buffer_contains_text("Found `yazi` version `yazi 0.2.5")
    assert_buffer_contains_text("Found `ya` version `Ya 0.2.5")
    assert_buffer_contains_text("OK yazi")
  end)

  it("warns if the yazi version is too old", function()
    mock_app_versions["yazi"] = "yazi 0.2.4 (f5a7ace 2024-06-23)"
    vim.cmd("checkhealth yazi")

    assert_buffer_contains_text(
      "yazi version is too old, please upgrade to 0.2.5 or newer"
    )
  end)

  it("warns if the ya version is too old", function()
    yazi.setup({ use_ya_for_events_reading = true })
    mock_app_versions["ya"] = "Ya 0.2.4 (f5a7ace 2024-06-23)"

    vim.cmd("checkhealth yazi")

    assert_buffer_contains_text(
      "WARNING The `ya` executable version (yazi command line interface) is too old."
    )
  end)

  it("warns when yazi is not found", function()
    mock_app_versions["yazi"] = "command not found"
  end)

  it("warns when ya is not found", function()
    mock_app_versions["ya"] = "command not found"

    vim.cmd("checkhealth yazi")

    assert_buffer_contains_text(
      "WARNING `ya --version` looks unexpected, saw `command not found`"
    )
  end)

  it(
    "warns when `ya` cannot be found but is set as the event_reader",
    function()
      stub(vim.fn, "executable", function(command)
        if command == "ya" then
          return 0
        else
          return 1
        end
      end)

      ---@type YaziConfig
      yazi.setup({
        use_ya_for_events_reading = true,
      })

      vim.cmd("checkhealth yazi")

      assert_buffer_contains_text(
        "ERROR You have opted in to using `ya` for events reading, but `ya` is not found on PATH."
      )
    end
  )

  it("warns when the yazi version and yazi version are not the same", function()
    mock_app_versions["yazi"] = "yazi 0.2.5 (f5a7ace 2024-07-23)"
    mock_app_versions["ya"] = "Ya 0.2.4 (f5a7ace 2024-06-23)"

    vim.cmd("checkhealth yazi")

    assert_buffer_contains_text(
      "WARNING The versions of `yazi` and `ya` do not match."
    )
  end)

  describe("the checks for `use_yazi_client_id_flag`", function()
    local yazi_help_output_with_client_id_flag_missing =
      [[Usage: yazi [OPTIONS] [ENTRY]

Arguments:
  [ENTRY]  Set the current working entry

Options:
      --cwd-file <CWD_FILE>            Write the cwd on exit to this file
      --chooser-file <CHOOSER_FILE>    Write the selected files to this file on open fired
      --clear-cache                    Clear the cache directory
      --local-events <LOCAL_EVENTS>    Report the specified local events to stdout
      --remote-events <REMOTE_EVENTS>  Report the specified remote events to stdout
      --debug                          Print debug information
  -V, --version                        Print version
  -h, --help                           Print help
      ]]

    before_each(function() end)

    it(
      "warns when the `--client-id` flag is not found in the yazi --help output",
      function()
        mock_app_versions["yazi --help"] =
          yazi_help_output_with_client_id_flag_missing
        yazi.setup({ use_yazi_client_id_flag = true })
        vim.cmd("checkhealth yazi")

        assert_buffer_contains_text(
          "You have enabled `use_yazi_client_id_flag` in your config, which means using the `--client-id` flag with yazi. However, this flag is not found in the `yazi --help` output. Please upgrade to the newest version of yazi or disable `use_yazi_client_id_flag`."
        )
      end
    )

    it(
      "does not warn when `use_yazi_client_id_flag` is not set and yazi doesn't support --client-id",
      function()
        mock_app_versions["yazi --help"] =
          yazi_help_output_with_client_id_flag_missing
        yazi.setup({ use_yazi_client_id_flag = false })
        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("use_yazi_client_id_flag")
      end
    )

    it(
      "does not warn when the `--client-id` flag is found in the yazi --help output",
      function()
        yazi.setup({ use_yazi_client_id_flag = true })
        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("use_yazi_client_id_flag")
      end
    )
  end)

  describe("the checks for `open_for_directories`", function()
    it(
      "instructs the user to load yazi on startup when `open_for_directories` is set",
      function()
        yazi.setup({ open_for_directories = true })
        vim.cmd("checkhealth yazi")

        assert_buffer_contains_text(
          "You have enabled `open_for_directories` in your config. Because of this, please make sure you are loading yazi when Neovim starts."
        )
      end
    )

    it(
      "does not instruct the user to load yazi on startup when `open_for_directories` is not set",
      function()
        yazi.setup({ open_for_directories = false })
        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("open_for_directories")
      end
    )
  end)

  describe("the checks for resolve_relative_path_application", function()
    it(
      "warns when the keymap for this integration is set but the resolver is missing",
      function()
        yazi.setup({
          integrations = {
            resolve_relative_path_application = "missing-nonexistent",
          },
        })

        vim.cmd("checkhealth yazi")

        assert_buffer_contains_text(
          "WARNING The `resolve_relative_path_application` (`missing-nonexistent`) is not found on PATH."
        )
      end
    )

    it(
      "does not warn when the keymap for this integration is not set",
      function()
        yazi.setup({
          keymaps = {
            copy_relative_path_to_selected_files = false,
          },
          integrations = {
            resolve_relative_path_application = "missing-nonexistent",
          },
        })

        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("resolve_relative_path_application")
      end
    )
  end)

  describe("suggestions for `use_ya_for_events_reading`", function()
    it(
      "suggests enabling `use_ya_for_events_reading` when yazi version is >= 0.3.0",
      function()
        mock_app_versions["yazi"] = "yazi 0.3.0 (f5a7ace 2024-06-23)"
        yazi.setup({ use_ya_for_events_reading = false })
        vim.cmd("checkhealth yazi")

        assert_buffer_contains_text(
          "You can enable `use_ya_for_events_reading` in your config to get access to new features. This is available for yazi versions >= 0.3.0."
        )
      end
    )

    it(
      "does not suggest enabling `use_ya_for_events_reading` when yazi version is < 0.3.0",
      function()
        mock_app_versions["yazi"] = "yazi 0.2.5 (f5a7ace 2024-06-23)"
        yazi.setup({ use_ya_for_events_reading = false })
        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("use_ya_for_events_reading")
      end
    )

    it(
      "does not suggest enabling `use_ya_for_events_reading` when it is already enabled",
      function()
        mock_app_versions["yazi"] = "yazi 0.3.0 (f5a7ace 2024-06-23)"
        yazi.setup({ use_ya_for_events_reading = true })
        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("use_ya_for_events_reading")
      end
    )
  end)

  describe("suggestions for `use_yazi_client_id_flag`", function()
    it(
      "suggests enabling `use_yazi_client_id_flag` when yazi version is >= 0.3.0",
      function()
        mock_app_versions["yazi"] = "yazi 0.3.0 (f5a7ace 2024-06-23)"
        yazi.setup({ use_yazi_client_id_flag = false })
        vim.cmd("checkhealth yazi")

        assert_buffer_contains_text(
          "You can enable `use_yazi_client_id_flag` in your config to get access to new features. This is available for yazi versions >= 0.3.0."
        )
      end
    )

    it(
      "does not suggest enabling `use_yazi_client_id_flag` when yazi version is < 0.3.0",
      function()
        mock_app_versions["yazi"] = "yazi 0.2.5 (f5a7ace 2024-06-23)"
        yazi.setup({ use_yazi_client_id_flag = false })
        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("use_yazi_client_id_flag")
      end
    )

    it(
      "does not suggest enabling `use_yazi_client_id_flag` when it is already enabled",
      function()
        mock_app_versions["yazi"] = "yazi 0.3.0 (f5a7ace 2024-06-23)"
        yazi.setup({ use_yazi_client_id_flag = true })
        vim.cmd("checkhealth yazi")

        assert_buffer_does_not_contain_text("use_yazi_client_id_flag")
      end
    )
  end)
end)
