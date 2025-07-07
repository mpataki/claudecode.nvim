require("tests.busted_setup")
require("tests.mocks.vim")

describe("enable_terminal configuration", function()
  local claudecode
  local mock_server
  local mock_lockfile
  local mock_selection
  local mock_terminal
  local terminal_opened = false
  local terminal_ensured_visible = false

  before_each(function()
    terminal_opened = false
    terminal_ensured_visible = false

    -- Mock dependencies
    mock_server = {
      start = function()
        return true, 12345
      end,
      stop = function()
        return true
      end,
      broadcast = function()
        return true
      end,
      get_client_count = function()
        return 0  -- Default to no clients
      end,
      get_status = function()
        return {
          running = true,
          client_count = 0,  -- Default to no clients
        }
      end,
    }

    mock_lockfile = {
      create = function()
        return true, nil, "test-token"
      end,
      remove = function()
        return true
      end,
      generate_auth_token = function()
        return "test-auth-token"
      end,
    }

    mock_selection = {
      enable = function() end,
      disable = function() end,
    }

    mock_terminal = {
      setup = function() end,
      open = function()
        terminal_opened = true
      end,
      ensure_visible = function()
        terminal_ensured_visible = true
      end,
      close = function() end,
      simple_toggle = function() end,
      focus_toggle = function() end,
    }

    -- Mock require to intercept module loading
    local original_require = require
    _G.require = function(mod)
      if mod == "claudecode.server.init" then
        return mock_server
      elseif mod == "claudecode.lockfile" then
        return mock_lockfile
      elseif mod == "claudecode.selection" then
        return mock_selection
      elseif mod == "claudecode.terminal" then
        return mock_terminal
      elseif mod == "claudecode.diff" then
        return {
          setup = function() end,
        }
      elseif mod == "claudecode.logger" then
        return {
          setup = function() end,
          info = function() end,
          warn = function() end,
          error = function() end,
          debug = function() end,
        }
      else
        return original_require(mod)
      end
    end

    -- Set up spy for nvim_create_user_command
    spy.on(vim.api, "nvim_create_user_command")

    -- Load the module
    package.loaded["claudecode"] = nil
    claudecode = require("claudecode")
  end)

  after_each(function()
    _G.require = require
  end)

  describe("when enable_terminal is true (default)", function()
    it("should register terminal commands", function()
      claudecode.setup({
        auto_start = false,
      })

      local registered_commands = {}
      for _, call in ipairs(vim.api.nvim_create_user_command.calls) do
        registered_commands[call.vals[1]] = true
      end

      assert.is_true(registered_commands["ClaudeCode"] ~= nil)
      assert.is_true(registered_commands["ClaudeCodeOpen"] ~= nil)
      assert.is_true(registered_commands["ClaudeCodeClose"] ~= nil)
      assert.is_true(registered_commands["ClaudeCodeFocus"] ~= nil)
    end)

    it("should launch terminal on @ mention when Claude not connected", function()
      claudecode.setup({
        auto_start = false,
      })

      -- Start the server
      claudecode.start()

      -- Simulate Claude not connected
      mock_server.get_status = function()
        return {
          running = true,
          client_count = 0,
        }
      end

      -- Send @ mention
      claudecode.send_at_mention("test.lua", 1, 10)

      assert.is_true(terminal_opened)
    end)

    it("should ensure terminal visible on @ mention when Claude connected", function()
      claudecode.setup({
        auto_start = false,
      })

      -- Start the server
      claudecode.start()

      -- Simulate Claude connected
      mock_server.get_status = function()
        return {
          running = true,
          client_count = 1,
        }
      end

      -- Send @ mention
      claudecode.send_at_mention("test.lua", 1, 10)

      assert.is_true(terminal_ensured_visible)
    end)
  end)

  describe("when enable_terminal is false", function()
    it("should not register terminal commands", function()
      claudecode.setup({
        auto_start = false,
        enable_terminal = false,
      })

      local registered_commands = {}
      for _, call in ipairs(vim.api.nvim_create_user_command.calls) do
        registered_commands[call.vals[1]] = true
      end

      assert.is_nil(registered_commands["ClaudeCode"])
      assert.is_nil(registered_commands["ClaudeCodeOpen"])
      assert.is_nil(registered_commands["ClaudeCodeClose"])
      assert.is_nil(registered_commands["ClaudeCodeFocus"])
    end)

    it("should not launch terminal on @ mention when Claude not connected", function()
      claudecode.setup({
        auto_start = false,
        enable_terminal = false,
      })

      -- Start the server
      claudecode.start()

      -- Simulate Claude not connected
      mock_server.get_status = function()
        return {
          running = true,
          client_count = 0,
        }
      end

      -- Send @ mention
      claudecode.send_at_mention("test.lua", 1, 10)

      assert.is_false(terminal_opened)
    end)

    it("should not ensure terminal visible on @ mention when Claude connected", function()
      claudecode.setup({
        auto_start = false,
        enable_terminal = false,
      })

      -- Start the server
      claudecode.start()

      -- Simulate Claude connected
      mock_server.get_status = function()
        return {
          running = true,
          client_count = 1,
        }
      end

      -- Send @ mention
      claudecode.send_at_mention("test.lua", 1, 10)

      assert.is_false(terminal_ensured_visible)
    end)

    it("should not call terminal setup during initialization", function()
      local terminal_setup_called = false
      mock_terminal.setup = function()
        terminal_setup_called = true
      end

      claudecode.setup({
        auto_start = false,
        enable_terminal = false,
      })

      assert.is_false(terminal_setup_called)
    end)
  end)

  describe("config validation", function()
    it("should accept boolean true for enable_terminal", function()
      local config = require("claudecode.config")
      local valid_config = {
        port_range = { min = 10000, max = 65535 },
        auto_start = true,
        enable_terminal = true,
        log_level = "info",
        track_selection = true,
        visual_demotion_delay_ms = 50,
        connection_wait_delay = 200,
        connection_timeout = 10000,
        queue_timeout = 5000,
        diff_opts = {
          auto_close_on_accept = true,
          show_diff_stats = true,
          vertical_split = true,
          open_in_current_tab = true,
        },
      }

      local success = pcall(config.validate, valid_config)
      assert.is_true(success)
    end)

    it("should accept boolean false for enable_terminal", function()
      local config = require("claudecode.config")
      local valid_config = {
        port_range = { min = 10000, max = 65535 },
        auto_start = true,
        enable_terminal = false,
        log_level = "info",
        track_selection = true,
        visual_demotion_delay_ms = 50,
        connection_wait_delay = 200,
        connection_timeout = 10000,
        queue_timeout = 5000,
        diff_opts = {
          auto_close_on_accept = true,
          show_diff_stats = true,
          vertical_split = true,
          open_in_current_tab = true,
        },
      }

      local success = pcall(config.validate, valid_config)
      assert.is_true(success)
    end)

    it("should reject non-boolean values for enable_terminal", function()
      local config = require("claudecode.config")
      local invalid_config = {
        port_range = { min = 10000, max = 65535 },
        auto_start = true,
        enable_terminal = "true", -- Invalid: string instead of boolean
        log_level = "info",
        track_selection = true,
        visual_demotion_delay_ms = 50,
        connection_wait_delay = 200,
        connection_timeout = 10000,
        queue_timeout = 5000,
        diff_opts = {
          auto_close_on_accept = true,
          show_diff_stats = true,
          vertical_split = true,
          open_in_current_tab = true,
        },
      }

      local success, err = pcall(config.validate, invalid_config)
      assert.is_false(success)
      assert.is_not_nil(string.find(tostring(err), "enable_terminal must be a boolean"))
    end)
  end)
end)