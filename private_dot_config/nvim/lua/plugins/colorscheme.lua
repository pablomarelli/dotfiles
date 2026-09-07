return {
  -- add gruvbox
  {
    "ellisonleao/gruvbox.nvim",
  },
  { "vague2k/vague.nvim" },
  {
    "cormacrelf/dark-notify",
    lazy = false,
    config = function()
      local dark_notify = require("dark_notify")
      dark_notify.run({
        schemes = {
          dark = { colorscheme = "gruvbox", background = "dark" },
          light = { colorscheme = "gruvbox", background = "light" },
        },
      })
      dark_notify.update()
    end,
  },
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- Set colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },
}
