return {
  'stevearc/oil.nvim',
  dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
--
  opts = {
    view_options = {
      show_hidden = true,
    },
    -- Disable conflicting keymaps
    keymaps = {
      ["<C-h>"] = false, -- Disable horizontal split (conflicts with tab navigation)
      ["<C-l>"] = false, -- Disable refresh (conflicts with tab navigation)
    },
  },
  keys = {
    {
      "<leader>e",
      ":Oil<cr>",
      desc = "Oil.nvim Filetree",
    },
  },
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
}
