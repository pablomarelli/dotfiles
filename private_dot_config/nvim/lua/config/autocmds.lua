-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Disable autoformat for python files
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "python" },
  callback = function()
    vim.b.autoformat = false
  end,
})

-- Disable copilot if installed
if vim.fn.exists(":Copilot") == 2 then
  vim.cmd(":Copilot disable")
end

vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
  pattern = "*",
  callback = function()
    local first_line = vim.fn.getline(1)
    if first_line:match("^#!/.*(bash|sh)") then
      vim.bo.filetype = "sh"
    end
  end,
})

-- Disable autoformat for python files
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "python" },
  callback = function()
    vim.b.autoformat = false
  end,
})
-- Enable autoformat ONLY for Go files
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "go" },
  callback = function()
    vim.b.autoformat = true
  end,
})
