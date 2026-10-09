-- Run with: nvim --headless -u NONE -i NONE -l tests/test_dark_notify.lua
local test_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
local root = vim.fn.fnamemodify(test_path, ":h:h")
local lazy_path = vim.env.LAZY_NVIM_PATH or (vim.fn.stdpath("data") .. "/lazy/lazy.nvim")
vim.opt.rtp:prepend(lazy_path)

local Spec = require("lazy.core.plugin").Spec
local Config = require("lazy.core.config")
Config.options = vim.deepcopy(Config.defaults)

local original_has = vim.fn.has
for _, platform in ipairs({ "linux", "win32", "mac" }) do
  vim.fn.has = function(feature)
    if feature == "mac" then
      return platform == "mac" and 1 or 0
    end
    return original_has(feature)
  end

  local specs = dofile(root .. "/private_dot_config/nvim/lua/plugins/colorscheme.lua")
  local resolved = Spec.new(specs, { pkg = false })
  assert(#resolved.notifs == 0, vim.inspect(resolved.notifs))
  assert(
    (resolved.plugins["dark-notify"] ~= nil) == (platform == "mac"),
    "dark-notify must only be enabled on macOS, platform: " .. platform
  )
  assert(resolved.plugins["gruvbox.nvim"], "gruvbox must remain available on " .. platform)
  print("PASS: colorscheme plugin selection on " .. platform)
end
vim.fn.has = original_has
