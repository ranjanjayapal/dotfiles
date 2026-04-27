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

      local function copy_text(text, label)
        if not text or text == "" then
          vim.notify("No path found to copy", vim.log.levels.INFO, { title = "Neo-tree" })
          return
        end

        vim.fn.setreg("+", text)
        vim.fn.setreg('"', text)
        vim.notify(label .. " copied", vim.log.levels.INFO, { title = "Neo-tree" })
      end

      local function relative_node_path(state, path)
        local root = state and state.path
        local normalized_path = vim.fs.normalize(path)

        if root and root ~= "" then
          local normalized_root = vim.fs.normalize(root)
          if normalized_path == normalized_root then
            return "."
          end

          local root_prefix = normalized_root
          if root_prefix:sub(-1) ~= "/" then
            root_prefix = root_prefix .. "/"
          end

          if normalized_path:sub(1, #root_prefix) == root_prefix then
            return normalized_path:sub(#root_prefix + 1)
          end
        end

        return vim.fn.fnamemodify(normalized_path, ":.")
      end

      local function copy_node_path(state, kind)
        local path = node_path(state)
        if not path then
          copy_text(nil)
          return
        end

        if kind == "relative" then
          copy_text(relative_node_path(state, path), "Relative path")
        elseif kind == "absolute" then
          copy_text(vim.fs.normalize(path), "Absolute path")
        elseif kind == "name" then
          copy_text(vim.fn.fnamemodify(vim.fs.normalize(path), ":t"), "Name")
        end
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

      opts.filesystem = opts.filesystem or {}
      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = opts.filesystem.window.mappings or {}
      opts.filesystem.window.mappings["c"] = "copy_to_clipboard"
      opts.filesystem.window.mappings["x"] = "cut_to_clipboard"
      opts.filesystem.window.mappings["p"] = "paste_from_clipboard"
      opts.filesystem.window.mappings["<leader>yr"] = {
        function(state)
          copy_node_path(state, "relative")
        end,
        desc = "Copy relative path",
      }
      opts.filesystem.window.mappings["<leader>ya"] = {
        function(state)
          copy_node_path(state, "absolute")
        end,
        desc = "Copy absolute path",
      }
      opts.filesystem.window.mappings["<leader>yn"] = {
        function(state)
          copy_node_path(state, "name")
        end,
        desc = "Copy name",
      }
    end,
  },
}
