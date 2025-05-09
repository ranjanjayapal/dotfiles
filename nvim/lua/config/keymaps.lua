-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.api.nvim_set_keymap("i", "jj", "<Esc>", { noremap = false })
vim.api.nvim_set_keymap("i", "jk", "<Esc>", { noremap = false })

-- Keybinding to open a Python scratchpad
vim.keymap.set("n", "<leader>sp", function()
  vim.cmd("enew") -- Open a new empty buffer
  vim.bo.buftype = "nofile" -- Mark it as a scratch buffer
  vim.bo.bufhidden = "hide" -- Hide buffer when abandoned
  vim.bo.swapfile = false -- Disable swapfile
  vim.bo.filetype = "python" -- Set filetype to Python
end, { desc = "Open Python Scratchpad" })

-- Keybinding to execute the Python scratchpad
vim.keymap.set("n", "<leader>se", function()
  vim.cmd("w !python") -- Write and execute the buffer with Python
end, { desc = "Execute Python Scratchpad" })
