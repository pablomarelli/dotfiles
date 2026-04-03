return {
  "mason-org/mason.nvim",
  opts = {
    ui = {
      border = "rounded",
    },
    ensure_installed = {
      -- Lua
      "stylua",
      -- Bash/Zsh
      "bash-language-server",
      "shellcheck",
      "shfmt",
      "beautysh",
      -- Python
      "pyright",
      "ruff",
      "ty",
      "debugpy",
      -- Golang
      "gopls",
      "gofumpt",
      "goimports",
      "delve",
      -- Typescript
      "typescript-language-server",
      "js-debug-adapter",
      "vtsls",
      -- HTML, CSS, Tailwind
      "tailwindcss-language-server",
      -- C
      "cmakelang",
      "cmakelint",
      "clangd",
      "codelldb",
      "neocmakelsp",
      -- SQL/Postgres
      "sqlfluff",
      "sqlfluff",
      -- JSON
      "json-lsp",
      -- YAML
      "yaml-language-server",
      -- TOML
      "taplo",
      -- Markdown
      "markdown-toc",
      "markdownlint-cli2",
      "marksman",
      -- Docker
      "dockerfile-language-server",
      "docker-compose-language-service",
      "hadolint",
      -- Helm
      "helm-ls",
      -- Terraform
      "terraform-ls",
      "tflint",
      -- Nvim
      "tree-sitter-cli"
    },
  },
}
