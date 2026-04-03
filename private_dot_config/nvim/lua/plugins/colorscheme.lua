return {
  -- add gruvbox
  { "ellisonleao/gruvbox.nvim" },
  { "vague2k/vague.nvim" },
  {
    "loctvl842/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      filter = "classic", -- default filter
    },
  },

  -- Set colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "monokai-pro",
    },
  },
}
