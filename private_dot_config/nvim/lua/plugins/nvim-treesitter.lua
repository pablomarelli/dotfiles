return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    -- Exclude python parser temporarily
    ensure_installed = { "lua", "vim", "vimdoc", "javascript", "html", "css", "json", "yaml" },
    ignore_install = { "python" },
    auto_install = false,
  }
}
