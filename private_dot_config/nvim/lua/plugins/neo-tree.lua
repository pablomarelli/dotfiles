return {
  "nvim-neo-tree/neo-tree.nvim",
  -- cmd = "Neotree",
  -- init = function()
  --   vim.g.neo_tree_remove_legacy_commands = true
  --   -- Disable netrw at the very start of your init.lua
  --   vim.g.loaded_netrw = 1
  --   vim.g.loaded_netrwPlugin = 1
  -- end,
  keys = {
    { "<leader>e", function()
      -- Force close any existing neo-tree windows first
      vim.cmd("Neotree close")
      -- Small delay to ensure cleanup
      vim.defer_fn(function()
        vim.cmd("Neotree reveal float")
      end, 10)
    end, desc = "Toggle Neo-tree (floating)" },
  },
  config = function(_, opts)
    require("neo-tree").setup(opts)
    
    -- Force neo-tree to stay floating and prevent edgy interference
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "neo-tree",
      callback = function()
        -- Prevent edgy from managing this window
        vim.b.edgy_disable = true
        vim.wo.winfixwidth = false
        vim.wo.winfixheight = false
      end,
    })
  end,
  opts = {
    -- sources = { "filesystem", "buffers", "git_status", "document_symbols" },
    -- close_if_last_window = true,
    -- -- auto_open = false,
    -- -- open_on_setup = false,
    -- -- open_on_setup_file = false,
    -- -- open_on_directory = false,
    -- enable_git_status = true,
    -- enable_diagnostics = true,
    window = {
      position = "float",
      width = 40,
      height = 20,
      mapping_options = {
        noremap = true,
        nowait = true,
      },
    },
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,
    -- document_symbols = {
    --   position = "left",
    -- },
    -- filesystem = {
    --   bind_to_cwd = false,
    --   follow_current_file = { enabled = true },
    --   use_libuv_file_watcher = true,
    --   filtered_items = {
    --     visible = true,
    --     show_hidden_count = true,
    --     hide_dotfiles = false,
    --     hide_gitignored = false,
    --     hide_by_name = {
    --       ".git",
    --       "node_modules",
    --       -- ".DS_Store",
    --       -- "thumbs.db",
    --     },
    --     never_show = {
    --       ".DS_Store",
    --       "thumbs.db",
    --     },
    --   },
    -- },
  },
}
