return {
  "vague2k/vague.nvim",

  -- {
  --   "LazyVim/LazyVim",
  --   opts = {
  --     colorscheme = "vague",
  --   },
  -- },

  config = function()
    require("vague").setup({
      transparent = false,
      style = {
        boolean = "none",
        number = "none",
        float = "none",
        error = "none",
        comments = "italic",
        conditionals = "none",
        functions = "none",
        headings = "bold",
        operators = "none",
        strings = "none",
        variables = "none",
        keywords = "none",
        keyword_return = "none",
        keywords_loop = "none",
        keywords_label = "none",
        keywords_exception = "none",
        builtin_constants = "none",
        builtin_functions = "none",
        builtin_types = "none",
        builtin_variables = "none",
      },
      colors = {
        -- Darker background might help
        bg = "#18191a",
        fg = "#cdcdcd",
      },
    })
  end,
}
