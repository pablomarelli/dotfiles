return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    {
      "nvim-telescope/telescope-live-grep-args.nvim",
      -- This will not install any breaking changes.
      -- For major updates, this must be adjusted manually.
      version = "^1.0.0",
    },
  },
  extensions_list = {
    "dir",
    "live_grep_args",
  },
  keys = {
    vim.keymap.set(
      "n",
      "<leader>fd",
      ":Telescope dir find_files<CR>",
      { noremap = true, silent = true, desc = "Find files in specific dir" }
    ),
    vim.keymap.set(
      "n",
      "<leader>fD",
      ":Telescope dir live_grep<CR>",
      { noremap = true, silent = true, desc = "Grep in specific dir" }
    ),
  },
}
