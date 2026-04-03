return {
  'kristijanhusak/vim-dadbod-ui',
  dependencies = {
    { 'tpope/vim-dadbod', lazy = true },
    { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
  },
  cmd = {
    'DBUI',
    'DBUIToggle',
    'DBUIAddConnection',
    'DBUIFindBuffer',
  },
  init = function()
    vim.g.db_ui_use_nerd_fonts = 1
    vim.g.db_ui_winwidth = 50
    vim.g.db_ui_save_location = vim.fn.expand("~/.config/dbqueries")
    vim.g.db_ui_execute_on_save = 0  -- Add this line to disable auto-run on save

    -- Export query results to CSV
    local function export_results_csv()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      if #lines == 0 then
        vim.notify("No results to export", vim.log.levels.WARN)
        return
      end
      local filename = vim.fn.expand("~/Desktop/query_results_" .. os.date("%Y%m%d_%H%M%S") .. ".csv")
      vim.fn.writefile(lines, filename)
      vim.notify("Exported to " .. filename, vim.log.levels.INFO)
    end

    -- Export query results to JSON
    local function export_results_json()
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      if #lines < 2 then
        vim.notify("No results to export", vim.log.levels.WARN)
        return
      end
      -- Parse the table-formatted output from dadbod
      -- First line contains headers separated by |
      local header_line = lines[1]
      local headers = {}
      for col in header_line:gmatch("[^|]+") do
        local trimmed = col:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
          table.insert(headers, trimmed)
        end
      end
      -- Parse data rows (skip separator lines that contain only -, +, |)
      local results = {}
      for i = 2, #lines do
        local line = lines[i]
        if not line:match("^[%-%+|%s]*$") and line:match("|") then
          local values = {}
          local col_idx = 1
          for val in line:gmatch("[^|]+") do
            local trimmed = val:match("^%s*(.-)%s*$")
            if col_idx <= #headers then
              values[headers[col_idx]] = trimmed
              col_idx = col_idx + 1
            end
          end
          if col_idx > 1 then
            table.insert(results, values)
          end
        end
      end
      local filename = vim.fn.expand("~/Desktop/query_results_" .. os.date("%Y%m%d_%H%M%S") .. ".json")
      local json = vim.fn.json_encode(results)
      vim.fn.writefile({ json }, filename)
      vim.notify("Exported " .. #results .. " rows to " .. filename, vim.log.levels.INFO)
    end

    -- Create commands
    vim.api.nvim_create_user_command("DBExportCSV", export_results_csv, { desc = "Export DB results to CSV" })
    vim.api.nvim_create_user_command("DBExportJSON", export_results_json, { desc = "Export DB results to JSON" })

    -- Keymaps for dbout filetype (query results buffer)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "dbout",
      callback = function()
        vim.keymap.set("n", "<leader>ec", export_results_csv, { buffer = true, desc = "Export to CSV" })
        vim.keymap.set("n", "<leader>ej", export_results_json, { buffer = true, desc = "Export to JSON" })
      end,
    })

    -- Configure table helpers
    vim.g.db_ui_table_helpers = {
      mysql = {
        List = "SELECT * FROM {table} LIMIT 10",
        Insert = "INSERT INTO {table} (column1, column2, column3)\nVALUES (?, ?, ?)",
        InsertMultiple = "INSERT INTO {table} (column1, column2, column3)\nVALUES\n  (?, ?, ?),\n  (?, ?, ?),\n  (?, ?, ?)",
        Update = "UPDATE {table}\nSET\n  column1 = value1,\n  column2 = value2\nWHERE id = ?",
        Delete = "DELETE FROM {table}\nWHERE id = ?",
        Count = "SELECT COUNT(*) FROM {table}",
        Describe = "DESCRIBE {table}",
        ShowIndexes = "SHOW INDEXES FROM {table}",
        ShowCreateTable = "SHOW CREATE TABLE {table}",
        Explain = "EXPLAIN {last_query}",
        ExportCSV = "SELECT * FROM {table} INTO OUTFILE '~/Desktop/{table}.csv' FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\\n'",
        ExportJSON = "SELECT JSON_ARRAYAGG(JSON_OBJECT(*)) FROM {table} INTO OUTFILE '~/Desktop/{table}.json'",
      },
      postgresql = {
        List = "SELECT * FROM {table} LIMIT 10",
        Insert = "INSERT INTO {table} (column1, column2, column3)\nVALUES ($1, $2, $3)\nRETURNING *",
        InsertMultiple = "INSERT INTO {table} (column1, column2, column3)\nVALUES\n  ($1, $2, $3),\n  ($4, $5, $6),\n  ($7, $8, $9)\nRETURNING *",
        Update = "UPDATE {table}\nSET\n  column1 = value1,\n  column2 = value2\nWHERE id = ?",
        Delete = "DELETE FROM {table}\nWHERE id = $1\nRETURNING *",
        Count = "SELECT COUNT(*) FROM {table}",
        Describe = "\\d+ {table}",
        ShowIndexes = "SELECT * FROM pg_indexes WHERE tablename = '{table}'",
        ShowConstraints = "SELECT * FROM information_schema.table_constraints WHERE table_name = '{table}'",
        Explain = "EXPLAIN ANALYZE {last_query}",
        ExportCSV = "\\COPY {table} TO '~/Desktop/{table}.csv' WITH CSV HEADER",
        ExportJSON = "\\COPY (SELECT json_agg(t) FROM {table} t) TO '~/Desktop/{table}.json'",
      },
      sqlite = {
        List = "SELECT * FROM {table} LIMIT 10",
        Insert = "INSERT INTO {table} (column1, column2, column3)\nVALUES (?, ?, ?)",
        InsertMultiple = "INSERT INTO {table} (column1, column2, column3)\nVALUES\n  (?, ?, ?),\n  (?, ?, ?),\n  (?, ?, ?)",
        Update = "UPDATE {table}\nSET\n  column1 = value1,\n  column2 = value2\nWHERE id = ?",
        Delete = "DELETE FROM {table}\nWHERE id = ?",
        Count = "SELECT COUNT(*) FROM {table}",
        Describe = ".schema {table}",
        ShowIndexes = "SELECT * FROM sqlite_master WHERE type = 'index' AND tbl_name = '{table}'",
        Explain = "EXPLAIN QUERY PLAN {last_query}",
        ExportCSV = ".mode csv\n.headers on\n.output ~/Desktop/{table}.csv\nSELECT * FROM {table};\n.output stdout\n.mode list",
        ExportJSON = ".mode json\n.output ~/Desktop/{table}.json\nSELECT * FROM {table};\n.output stdout\n.mode list",
      }
    }
  end,
}
