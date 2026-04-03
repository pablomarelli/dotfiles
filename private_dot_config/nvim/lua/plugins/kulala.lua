return {
  {
    "mistweaverco/kulala.nvim",
    ft = "http",
    keys = {
      {
        "<leader>Re",
        function()
          require("kulala").set_selected_env()
        end,
        ft = { "http", "rest" },
        desc = "Select environment",
      },
    },
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "http",
        callback = function()
          vim.opt_local.conceallevel = 0
        end,
      })
      require("kulala").setup({
        default_env = "dev", -- Your default environment
        -- Other configuration options
      })
    end,
  },
}
