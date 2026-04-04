-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Open previous telescope windows
-- vim.keymap.set(
--   "n",
--   "<leader>sx",
--   require("telescope.builtin").resume,
--   { noremap = true, silent = true, desc = "Resume" }
-- )

-- Navigate between tmux panes
vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { noremap = true, silent = true })

-- Change inside word
-- vim.keymap.set("n", "<CR>", "ciw", { noremap = true, silent = true })
vim.keymap.set('n', '<CR>', function()
  if vim.bo.modifiable then
    return 'ciw'
  else
    return '<CR>'
  end
end, { expr = true, noremap = true })


-- Format JSON
vim.keymap.set("n", "<leader>cj", "<cmd>%!jq .<CR>", { noremap = true, silent = true, desc = "Format json using jq" })

-- Reload vim config
-- vim.keymap.set("n", "<leader>r", "<cmd>luafile $MYVIMRC<CR>", { noremap = true, silent = true })

-- Center screen after half-page scroll
vim.keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true, silent = true, desc = "Keep down page scroll centered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true, silent = true, desc = "Keep up page scroll centered" })

-- Yank without cursor offset
vim.keymap.set("v", "y", "ygv<esc>", { noremap = true, silent = true, desc = "Yank without cursor offset" })

-- Move selected lines up/down
-- vim.keymap.set("x", "K", ":move '<-2<CR>gv-gv", { desc = "Move selected lines up" })
-- vim.keymap.set("x", "J", ":move '>+1<CR>gv-gv", { desc = "Move selected lines down" })
vim.keymap.set("x", "K", ":move '<-2<CR>gv", { desc = "Move selected lines up" })
vim.keymap.set("x", "J", ":move '>+1<CR>gv", { desc = "Move selected lines down" })

-- Kulala keymaps
-- vim.keymap.set("n", "<leader>rp", ":lua require('kulala').jump_prev()<CR>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<leader>rn", ":lua require('kulala').jump_next()<CR>", { noremap = true, silent = true })
-- vim.keymap.set("n", "<leader>rr", ":lua require('kulala').run()<CR>", { noremap = true, silent = true })

-- Resize window using <ctrl> arrow keys
-- vim.keymap.set("n", "<C-S-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
-- vim.keymap.set("n", "<C-S-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
-- vim.keymap.set("n", "<C-S-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
-- vim.keymap.set("n", "<C-S-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

vim.api.nvim_set_keymap("n", "<C-S-Up>", "<cmd>resize +2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-S-Down>", "<cmd>resize -2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-S-Left>", "<cmd>vertical resize -2<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-S-Right>", "<cmd>vertical resize +2<CR>", { noremap = true, silent = true })

-- Yank keymaps from reddit
vim.keymap.set("n", '<leader>y', '"+y', { noremap = true, silent = true, desc = 'Yank to clipboard' })
vim.keymap.set({"v", "x"}, '<leader>y', '"+y', { noremap = true, silent = true, desc = 'Yank to clipboard' })
-- vim.keymap.set({"n", "v", "x"}, '<leader>yy', '"+yy', { noremap = true, silent = true, desc = 'Yank line to clipboard' })
vim.keymap.set({"n", "v", "x"}, '<leader>Y', '"+yy', { noremap = true, silent = true, desc = 'Yank line to clipboard' })
-- vim.keymap.set({"n", "v", "x"}, '<C-a>', 'gg0vG$', { noremap = true, silent = true, desc = 'Select all' })
vim.keymap.set({'n', 'v', 'x'}, '<leader>p', '"+p', { noremap = true, silent = true, desc = 'Paste from clipboard' })
-- vim.keymap.set('i', '<C-p>', '<C-r>+', { noremap = true, silent = true, desc = 'Paste from clipboard from within insert mode' })
vim.keymap.set("x", "<leader>P", '"_dP', { noremap = true, silent = true, desc = 'Paste over selection without erasing unnamed register' })
--

-- Python snippets
-- vim.api.nvim_set_keymap("v", "<leader>pl", [[yoprint(f'<Esc>pa: {}<Esc>hp')]], { noremap = true, silent = true })
-- vim.fn.setreg("l", "yoprint(f'pa: {}hp'")
--

-- Diffview keymaps
vim.keymap.set("n", "<leader>gdf", "<cmd>DiffviewFileHistory %<CR>", 
  { noremap = true, silent = true, desc = "Git file history (diffview)" })
vim.keymap.set("n", "<leader>gdh", "<cmd>DiffviewFileHistory<CR>", 
  { noremap = true, silent = true, desc = "Git repo history (diffview)" })
vim.keymap.set("n", "<leader>gdm", function()
  vim.fn.system("git rev-parse --verify main")
  local base_branch = vim.v.shell_error == 0 and "main" or "master"
  vim.cmd("DiffviewOpen " .. base_branch .. "...HEAD --imply-local")
end, { noremap = true, silent = true, desc = "Git diff vs default branch (diffview)" })
vim.keymap.set("n", "<leader>gdd", function()
  local view = require("diffview.lib").get_current_view()
  if view then
    vim.cmd("DiffviewClose")
  else
    vim.cmd("DiffviewOpen")
  end
end, { noremap = true, silent = true, desc = "Toggle diffview" })
