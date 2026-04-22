return {
  "princejoogie/dir-telescope.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  lazy = true,
  cmd = {
    "FileInDirectory",
    "GrepInDirectory",
  },
  config = function()
    require("dir-telescope").setup({
      -- these are the default options set
      hidden = true,
      no_ignore = false,
      show_preview = true,
    })
  end,
}
