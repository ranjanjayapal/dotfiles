return {
  "zbirenbaum/copilot.lua",
  opts = {
    suggestion = {
      enabled = not vim.g.ai_cmp,
      auto_trigger = true,
      hide_during_completion = vim.g.ai_cmp,
      keymap = {
        accept = false, -- handled by nvim-cmp / blink.cmp
        next = "<M-]>",
        prev = "<M-[>",
      },
      model = "claude-3.5-sonnet",
    },
    panel = { enabled = false },
    filetypes = {
      markdown = true,
      help = true,
    }
  }
}
