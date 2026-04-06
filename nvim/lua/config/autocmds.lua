-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

local ok_convert, convert = pcall(require, "snacks.image.convert")
local ok_image, image = pcall(require, "snacks.image")
local ok_util, util = pcall(require, "snacks.image.util")
if ok_convert and ok_image and ok_util and not convert._png_passthrough_patched then
  local original = convert.convert

  convert.convert = function(opts)
    local src = opts and opts.src or nil
    if src and image.supports_file(src) and vim.fn.fnamemodify(src, ":e"):lower() == "png" and vim.fn.filereadable(src) == 1 then
      local info = {
        format = "png",
        size = util.dim(src),
        dpi = { width = 96, height = 96 },
      }
      local fake = {
        src = src,
        file = src,
        meta = { src = src, info = info },
        steps = {},
      }

      function fake:done()
        return true
      end

      function fake:error()
        return nil
      end

      function fake:ready()
        return true
      end

      function fake:current()
        return { name = "png" }
      end

      function fake:run()
      end

      function fake:abort()
      end

      return fake
    end

    return original(opts)
  end

  convert._png_passthrough_patched = true
end
