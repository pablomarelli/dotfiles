-- gh.nvim: GitHub PR code review in Neovim
--
-- Usage:
--   1. Open Neovim in a repo with PRs
--   2. <leader>gpo -> Select PR to review
--   3. gh.nvim checks out the PR branch locally (full LSP works)
--   4. Navigate with <leader>gpp (panel), <leader>gpn (next thread)
--   5. Add comments with <leader>gpa (works in visual mode for multi-line)
--   6. Submit review with <leader>gps
--   7. Use <leader>gpv to view PR diff in diffview (compares against main/master)
--
-- Prerequisites:
--   gh auth status  # Must be authenticated

return {
  {
    "ldelossa/litee.nvim",
    config = function()
      require("litee.lib").setup()
    end,
  },
  {
    "ldelossa/gh.nvim",
    dependencies = { "ldelossa/litee.nvim" },
    config = function()
      require("litee.gh").setup()
    end,
    keys = {
      { "<leader>gpo", "<cmd>GHOpenPR<cr>", desc = "Open PR" },
      { "<leader>gpc", "<cmd>GHClosePR<cr>", desc = "Close PR" },
      { "<leader>gpd", "<cmd>GHPRDetails<cr>", desc = "PR Details" },
      { "<leader>gpr", "<cmd>GHRefreshPR<cr>", desc = "Refresh PR" },
      { "<leader>gpt", "<cmd>GHToggleThread<cr>", desc = "Toggle Thread" },
      { "<leader>gpn", "<cmd>GHNextThread<cr>", desc = "Next Thread" },
      { "<leader>gpa", "<cmd>GHCreateThread<cr>", desc = "Add Comment", mode = { "n", "v" } },
      { "<leader>gps", "<cmd>GHSubmitReview<cr>", desc = "Submit Review" },
      { "<leader>gpb", "<cmd>GHStartReview<cr>", desc = "Begin Review" },
      { "<leader>gpp", "<cmd>LTPanel<cr>", desc = "Toggle Panel" },
      {
        "<leader>gpv",
        function()
          -- Get the merge base between current HEAD and main/master
          local base = vim.fn.system("git merge-base HEAD main 2>/dev/null"):gsub("\n", "")
          if base == "" then
            base = vim.fn.system("git merge-base HEAD master 2>/dev/null"):gsub("\n", "")
          end
          if base ~= "" then
            vim.cmd("DiffviewOpen " .. base .. "...HEAD")
          else
            vim.notify("Could not find base branch (main/master)", vim.log.levels.ERROR)
          end
        end,
        desc = "View PR Diff",
      },
      { "<leader>gpf", "<cmd>DiffviewToggleFiles<cr>", desc = "Toggle Files Panel" },
    },
  },
}
