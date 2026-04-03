return {
  "tpope/vim-fugitive",
  opts = {},
  keys = {
    vim.keymap.set(
      "n",
      "<leader>gb",
      ":Git blame<CR>",
      { noremap = true, silent = true, desc = "Fugitive git blame buffer" }
    ),
  },
}
