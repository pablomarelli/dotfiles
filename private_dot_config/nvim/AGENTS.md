# Agent Guidelines for Neovim Configuration

## Build/Lint/Test Commands
- **Format Lua**: `stylua .` (uses 2-space indentation, 120 column width)
- **Shellcheck**: `shellcheck <file>` for shell scripts
- **Format Shell**: `shfmt -i 4 <file>`
- **Python format**: `ruff format <file>` and `ruff check --fix <file>`
- **No test suite** - this is a personal Neovim configuration

## Code Style Guidelines
- **Language**: Lua for configuration, with some shell/Python scripts
- **Indentation**: 2 spaces for Lua, 4 spaces for shell scripts
- **Line length**: 120 characters maximum
- **Imports**: Use `require()` for Lua modules, follow LazyVim plugin structure
- **Plugin structure**: Return table from `lua/plugins/*.lua` files with plugin specs
- **Comments**: Use `--` for Lua comments, avoid unnecessary comments
- **Naming**: Use snake_case for Lua variables/functions, kebab-case for file names

## Architecture
- **Structure**: LazyVim-based configuration with custom plugins in `lua/plugins/`
- **Configuration**: Core config in `lua/config/`, plugin configs in `lua/plugins/`
- **Plugin management**: Uses lazy.nvim with plugin specs
- **Formatters**: Configured via conform.nvim plugin
- **LSP**: Managed through mason.nvim and nvim-lspconfig

## Error Handling
- Use vim.notify() for user notifications
- Wrap risky operations in pcall() when appropriate
- Follow LazyVim patterns for error handling in plugin configurations