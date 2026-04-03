-- LLM Context Helper
-- Provides context information for AI assistants

local M = {}

-- Get current file context
function M.get_file_context()
  local buf = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(buf)
  local filetype = vim.bo[buf].filetype
  local lines = vim.api.nvim_buf_line_count(buf)
  
  if filename == "" then
    return "No file currently open"
  end
  
  local relative_path = vim.fn.fnamemodify(filename, ":~:.")
  return string.format(
    "Current file: %s\nType: %s\nLines: %d",
    relative_path,
    filetype ~= "" and filetype or "unknown",
    lines
  )
end

-- Get project context
function M.get_project_context()
  local cwd = vim.fn.getcwd()
  local project_name = vim.fn.fnamemodify(cwd, ":t")
  
  -- Check for common project files
  local project_files = {
    "package.json",
    "requirements.txt",
    "Cargo.toml",
    "go.mod",
    "pom.xml",
    "README.md",
    ".gitignore"
  }
  
  local found_files = {}
  for _, file in ipairs(project_files) do
    if vim.fn.filereadable(file) == 1 then
      table.insert(found_files, file)
    end
  end
  
  local context = string.format("Project: %s\nPath: %s", project_name, cwd)
  if #found_files > 0 then
    context = context .. "\nProject files: " .. table.concat(found_files, ", ")
  end
  
  return context
end

-- Get git context
function M.get_git_context()
  local git_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
  if git_branch == "" then
    return "Not in a git repository"
  end
  
  local git_status = vim.fn.system("git status --porcelain 2>/dev/null")
  local has_changes = git_status ~= ""
  
  return string.format(
    "Git branch: %s%s",
    git_branch,
    has_changes and " (has uncommitted changes)" or " (clean)"
  )
end

-- Get LSP context
function M.get_lsp_context()
  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf })
  
  if #clients == 0 then
    return "No LSP clients attached"
  end
  
  local client_names = {}
  for _, client in ipairs(clients) do
    table.insert(client_names, client.name)
  end
  
  return "LSP clients: " .. table.concat(client_names, ", ")
end

-- Get comprehensive context
function M.get_full_context()
  local context_parts = {
    M.get_file_context(),
    M.get_project_context(),
    M.get_git_context(),
    M.get_lsp_context()
  }
  
  return table.concat(context_parts, "\n\n")
end

-- Copy context to clipboard
function M.copy_context_to_clipboard()
  local context = M.get_full_context()
  vim.fn.setreg("+", context)
  vim.notify("Context copied to clipboard!", vim.log.levels.INFO)
end

-- Show context in a floating window
function M.show_context_window()
  local context = M.get_full_context()
  local lines = vim.split(context, "\n")
  
  -- Create floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " LLM Context ",
    title_pos = "center"
  })
  
  -- Close on escape or q
  vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
end

return {
  "nvim-lua/plenary.nvim", -- Just a placeholder, this is a utility module
  config = function()
    -- Set up keymaps
    vim.keymap.set("n", "<leader>cx", M.show_context_window, { desc = "Show LLM Context" })
    vim.keymap.set("n", "<leader>cy", M.copy_context_to_clipboard, { desc = "Copy Context to Clipboard" })
    
    -- Make the module globally available
    _G.LLMContext = M
  end
}
