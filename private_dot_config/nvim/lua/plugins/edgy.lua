return {
  "folke/edgy.nvim",
  event = "VeryLazy",
  init = function()
    vim.opt.laststatus = 3
    vim.opt.splitkeep = "screen"
  end,
  opts = {
      left = {
        -- Add dadbod-ui to left panel
        {
          title = "Database",
          ft = "dbui",
          size = { width = 0.2 },
        },
        -- Add other panels you want managed by edgy
        "neo-tree", -- This will be ignored due to exclude, but kept for reference
      },
      bottom = {
        -- Dadbod query results
        {
          ft = "dbout",
          title = "DB Results",
          size = { height = 0.5 },
        },
        -- Terminal and other bottom panels
        {
          ft = "toggleterm",
          size = { height = 0.4 },
        },
        {
          ft = "trouble",
          size = { height = 0.2 },
        },
        {
          ft = "qf",
          title = "QuickFix",
          size = { height = 0.2 },
        },
      },
      right = {
        -- Right side panels
        {
          ft = "help",
          size = { width = 80 },
        },
      },
      top = {},
      -- Only exclude neo-tree to keep it floating
      exclude = {
        ft = { "neo-tree" },
      },
      -- edgebar animations
      animate = {
        enabled = false,
      },
  }
}
