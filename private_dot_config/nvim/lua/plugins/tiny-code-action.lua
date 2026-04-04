return {
  "rachartier/tiny-code-action.nvim",
  dependencies = {
    { "nvim-lua/plenary.nvim" },

    -- optional picker via telescope
    -- {"nvim-telescope/telescope.nvim"},
    -- optional picker via fzf-lua
    -- {"ibhagwan/fzf-lua"},
    -- .. or via snacks
    {
      "folke/snacks.nvim",
      opts = {
        terminal = {},
      },
    },
  },
  event = "LspAttach",
  keys = {
    {
      "<leader>ca",
      function()
        require("tiny-code-action").code_action()
      end,
      mode = { "n", "x" },
      desc = "Code Action",
    },
  },
  opts = {
    --- The backend to use, currently only "vim", "delta", "difftastic", "diffsofancy" are supported
    backend = "vim",
  },
}
