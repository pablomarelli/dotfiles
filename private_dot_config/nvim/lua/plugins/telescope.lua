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
    { "<leader>fd", "<cmd>FileInDirectory<cr>", desc = "Find files in specific dir" },
    { "<leader>fD", "<cmd>GrepInDirectory<cr>", desc = "Grep in specific dir" },
  },
}
