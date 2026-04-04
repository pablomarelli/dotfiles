return {
  "nvim-lspconfig",
  ---@class PluginLspOpts
  opts = {
    inlay_hints = { enabled = false },
    float = {
      border = "rounded",
    },
    servers = {
      ["*"] = {
        keys = {
          { "<leader>ca", false, mode = { "n", "x" } },
          { "K", function() vim.lsp.buf.hover({ border = "rounded" }) end, desc = "Hover" },
          {
            "gK",
            function() vim.lsp.buf.signature_help({ border = "rounded" }) end,
            desc = "Signature Help",
            has = "signatureHelp",
          },
          {
            "<c-k>",
            function() vim.lsp.buf.signature_help({ border = "rounded" }) end,
            mode = "i",
            desc = "Signature Help",
            has = "signatureHelp",
          },
        },
      },
      -- -- pylsp
      -- pylsp = {
      --   settings = {
      --     pylsp = {
      --       plugins = {
      --         mccabe = {
      --           enabled = true,
      --         },
      --         pycodestyle = {
      --           enabled = false,
      --         },
      --         flake8 = {
      --           enabled = false,
      --         },
      --         rope_autoimport = {
      --           enabled = true,
      --         },
      --         rope_completion = {
      --           enabled = true,
      --         },
      --       },
      --     },
      --   },
      -- },
      -- pyright (commented out to use pylsp instead)
      -- pyright = {
      --   settings = {
      --     python = {
      --       analysis = {
      --         typeCheckingMode = "off", -- Type checking level: "off", "basic", "strict"
      --         autoSearchPaths = true, -- Automatically search paths for imports
      --         useLibraryCodeForTypes = true, -- Use library code for type analysis
      --         -- diagnosticMode = "workspace", -- Diagnostics for "openFilesOnly" or "workspace"
      --         -- stubPath = "typings", -- Path to custom type stubs
      --         -- logLevel = "Information", -- Logging level: "Error", "Warning", "Information"
      --         autoImportCompletions = true, -- Enable completions for auto-imports
      --         -- diagnosticSeverityOverrides = { -- Customize severity for specific diagnostics
      --         --   reportOptionalSubscript = "error", -- Severity for subscript issues
      --         --   reportUnusedImport = "warning", -- Customize unused import severity
      --         -- },
      --         -- extraPaths = { "src", "lib" }, -- Add additional import paths
      --       },
      --     },
      --   },
      --   -- root_dir = function(fname) -- Customize project root detection
      --   --   return require("lspconfig").util.find_git_ancestor(fname) or vim.loop.os_homedir()
      --   -- end,
      --   -- single_file_support = true, -- Enable single-file support for non-project files
      --   -- cmd = { "pyright-langserver", "--stdio" }, -- Command to run the LSP
      --   filetypes = { "python" }, -- Specify filetypes
      --   -- init_options = { -- Initialization options for pyright
      --   --   hostInfo = "neovim",
      --   -- },
      -- },
      -- ruff = {
      --   init_options = {
      --     settings = {
      --       format = {
      --         preview = true,
      --       },
      --     },
      --   },
      -- },
    },
  },
}
