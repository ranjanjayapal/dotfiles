return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      local app_by_ext = {
        bmp = "/System/Applications/Preview.app",
        gif = "/System/Applications/Preview.app",
        heic = "/System/Applications/Preview.app",
        jpeg = "/System/Applications/Preview.app",
        jpg = "/System/Applications/Preview.app",
        png = "/System/Applications/Preview.app",
        tif = "/System/Applications/Preview.app",
        tiff = "/System/Applications/Preview.app",
        webp = "/System/Applications/Preview.app",
        ply = { kind = "meshlab" },
        stl = { kind = "meshlab" },
      }

      local function node_path(state)
        local node = state and state.tree and state.tree:get_node()
        if not node then
          return nil
        end

        return node.path or node:get_id()
      end

      local function open_in_app(path)
        local ext = vim.fn.fnamemodify(path, ":e"):lower()
        local app = app_by_ext[ext]

        if app then
          if app.kind == "meshlab" then
            local script = string.format(
              'tell application id "com.vcg.meshlab" to open POSIX file "%s"',
              path:gsub('\\', '\\\\'):gsub('"', '\\"')
            )
            vim.fn.jobstart({ "osascript", "-e", script }, { detach = true })
            vim.defer_fn(function()
              vim.fn.jobstart({
                "osascript",
                "-e",
                'tell application id "com.vcg.meshlab" to reopen',
                "-e",
                'tell application id "com.vcg.meshlab" to activate',
              }, { detach = true })
            end, 300)
          else
            vim.fn.jobstart({ "open", "-a", app, path }, { detach = true })
          end
          return
        end

        vim.fn.jobstart({ "open", path }, { detach = true })
      end

      local function open_in_finder(path)
        if vim.fn.isdirectory(path) == 1 then
          vim.fn.jobstart({ "open", path }, { detach = true })
          return
        end

        vim.fn.jobstart({ "open", "-R", path }, { detach = true })
      end

      opts.window = opts.window or {}
      opts.window.mappings = opts.window.mappings or {}

      opts.window.mappings["O"] = function(state)
        local path = node_path(state)
        if path then
          open_in_app(path)
        end
      end

      opts.window.mappings["<S-o>"] = opts.window.mappings["O"]
      opts.window.mappings["<leader>fo"] = function(state)
        local path = node_path(state)
        if path then
          open_in_finder(path)
        end
      end
    end,
  },
}
