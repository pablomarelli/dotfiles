return {
  "lewis6991/gitsigns.nvim",
  opts = {
    signs = {
      add = { hl = "GitSignsAdd", text = "▉" },
      change = { hl = "GitSignsChange", text = "▉" },
      delete = { hl = "GitSignsDelete", text = "▉" },
    },
    -- optional: gutter line highlight
    signcolumn = true,
    numhl = false,
    linehl = false,
    preview_config = {
      border = "rounded",
      style = "minimal",
    },
  },
}
