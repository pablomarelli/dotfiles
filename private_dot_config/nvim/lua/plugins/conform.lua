-- print("Loading conform.nvim configuration")
--
return {
  "stevearc/conform.nvim",
  keys = {
    {
      "<leader>cf",
      function()
        local ok_conform, conform = pcall(require, "conform")
        local ok_gitsigns, gitsigns = pcall(require, "gitsigns")

        if not ok_conform or not ok_gitsigns then
          vim.notify("conform.nvim or gitsigns.nvim is not available", vim.log.levels.ERROR)
          return
        end

        local hunks = gitsigns.get_hunks(0)
        if not hunks or vim.tbl_isempty(hunks) then
          vim.notify("No modified hunks to format", vim.log.levels.INFO)
          return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local formatted = 0

        for i = #hunks, 1, -1 do
          local hunk = hunks[i]
          local added = hunk.added

          if added and added.count > 0 then
            local start_line = added.start
            local end_line = added.start + added.count - 1
            local last_line = vim.api.nvim_buf_get_lines(bufnr, end_line - 1, end_line, false)[1] or ""

            conform.format({
              async = false,
              bufnr = bufnr,
              lsp_format = "fallback",
              timeout_ms = 1000,
              range = {
                start = { start_line, 0 },
                ["end"] = { end_line, #last_line },
              },
            })

            formatted = formatted + 1
          end
        end

        if formatted == 0 then
          vim.notify("No added or changed lines to format", vim.log.levels.INFO)
        end
      end,
      mode = "n",
      desc = "Format modified hunks",
    },
    {
      "<leader>cF",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = "n",
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      fish = { "fish_indent" },
      sh = { "shfmt" },
      python = { "ruff_format", "ruff_fix" },
      sql = { "sql_formatter" },
      ["*"] = { "injected" }, -- enables injected-lang formatting for all filetypes
    },
    formatters = {
      shfmt = {
        prepend_args = { "-i", "4" },
      },
      sql_formatter = {
        args = {
          "--config",
          vim.fn.json_encode({
            language = "sql",
            keywordCase = "upper",
            functionCase = "upper",
            dataTypeCase = "upper",
            indentStyle = "standard",
            tabWidth = 2,
            useTabs = false,
            linesBetweenQueries = 1,
          }),
        },
      },
    },
  },
}
