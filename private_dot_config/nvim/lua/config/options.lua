-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Show file location in project top right
vim.opt.winbar = "%=%m %f"

-- Select LSP for python ruff
vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"

-- Change highlight color for illuminate and for lsp
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("Color", {}),
  pattern = "*",
  callback = function()
    -- vim.api.nvim_set_hl(0, "LspReferenceRead", { fg = "#FF0000", bg = "#ffcc00" })
    -- vim.api.nvim_set_hl(0, "LspReferenceWrite", { fg = "#FF0000" })
    -- vim.api.nvim_set_hl(0, "LspReferenceText", { fg = "#FF0000" })

    -- GitSigns
    -- anywhere after colorscheme or in an after/plugin file
    vim.api.nvim_set_hl(0, "GitSignsAdd", { fg = "#3CFF33" })
    vim.api.nvim_set_hl(0, "GitSignsChange", { fg = "#FFD700" })
    vim.api.nvim_set_hl(0, "GitSignsDelete", { fg = "#FF5555" })

    -- Non used variables color
    vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", { fg = "#878787" })
  end,
})

-- Minimal number of screen lines to keep above and below the cursor
vim.opt.scrolloff = 15

-- Reactivate line wrapping
vim.opt.wrap = true

-- Disable autoformat
vim.g.autoformat = false

-- Python 3 provider
vim.g.python3_host_prog = "/Users/pablomarelli/venvs/nvim-python3/bin/python"

-- Python 2 provider
vim.g.python_host_prog = "/Users/pablomarelli/venvs/nvim-python2/bin/python"

-- Set http as filetype
vim.filetype.add({
  extension = {
    ["http"] = "http",
  },
})

-- Avante
-- Views can only be fully collapsed with the global statusline
vim.opt.laststatus = 3

vim.g.snacks_animate = false

-- vim.opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"
vim.opt.clipboard = ""

-- MACROS
vim.fn.setreg("l", "yoprint(f'pa: {}hp'")

vim.g.conceallevel = 0

-- Diagnostic configuration with borders
vim.diagnostic.config({
  float = { border = "rounded" }
})

-- Force truecolor support
vim.opt.termguicolors = true

vim.o.winborder = "rounded"
