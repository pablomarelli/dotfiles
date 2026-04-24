return {
  'stevearc/oil.nvim',
  dependencies = {
    { "nvim-mini/mini.icons", opts = {} },
    "SirZenith/oil-vcs-status",
  },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  --
  opts = {
    win_options = {
      number = false,
      relativenumber = false,
      signcolumn = "yes:1",
    },
    view_options = {
      show_hidden = true,
    },
    -- Disable conflicting keymaps
    keymaps = {
      ["<C-h>"] = false, -- Disable horizontal split (conflicts with tab navigation)
      ["<C-l>"] = false, -- Disable refresh (conflicts with tab navigation)
    },
  },
  config = function(_, opts)
    require("oil").setup(opts)
    local StatusType = require("oil-vcs-status.constant.status").StatusType

    require("oil-vcs-status").setup({
      status_symbol = {
        [StatusType.Added] = "+",
        [StatusType.Copied] = "C",
        [StatusType.Deleted] = "-",
        [StatusType.Ignored] = "!",
        [StatusType.Modified] = "~",
        [StatusType.Renamed] = ">",
        [StatusType.TypeChanged] = "T",
        [StatusType.Unmodified] = " ",
        [StatusType.Unmerged] = "U",
        [StatusType.Untracked] = "?",
        [StatusType.External] = "X",
      },
    })
  end,
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
