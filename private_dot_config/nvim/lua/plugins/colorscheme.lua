return {
  -- add gruvbox
  { "ellisonleao/gruvbox.nvim",
    -- opts = { background = "light" },
  },
  { "vague2k/vague.nvim" },
  -- {
  --   "cormacrelf/dark-notify",
  --   config = function()
  --     require("dark_notify").run({
  --       schemes = {
  --         dark = "monokai-pro-classic",
  --         light = "gruvbox",
  --       },
  --     })
  --   end,
  -- },
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
