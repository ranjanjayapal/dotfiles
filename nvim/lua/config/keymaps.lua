-- Image helpers and keymaps.

local image = require("snacks.image")

local function notify_no_image(message)
  vim.notify(message or "No supported image found under cursor", vim.log.levels.INFO, { title = "Image" })
end

local image_browser = {
  path = nil,
  dir = nil,
  files = {},
  index = 0,
}

local hover_win

local function trim_path_token(token)
  return token:gsub("^[%[%(%{<\"'`]+", ""):gsub("[%]%)%}>\"'`.,;:!?]+$", "")
end

local function neo_tree_selected_path()
  local ok_manager, manager = pcall(require, "neo-tree.sources.manager")
  if not ok_manager then
    return nil
  end

  local state = manager.get_state_for_window()
  if not state or not state.tree then
    return nil
  end

  local node = state.tree:get_node()
  if node then
    return node.path or node:get_id()
  end

  return nil
end

local function resolve_candidate(candidate)
  if not candidate or candidate == "" then
    return nil
  end

  local resolved = Snacks.image.doc.resolve(0, candidate)
  if resolved ~= "" and image.supports_file(resolved) and vim.fn.filereadable(resolved) == 1 then
    return vim.fs.normalize(resolved)
  end

  if vim.fn.isdirectory(candidate) == 1 then
    return vim.fs.normalize(candidate)
  end

  return nil
end

local function is_image_file(path)
  return path and path ~= "" and image.supports_file(path) and vim.fn.filereadable(path) == 1
end

local function collect_image_siblings(path)
  if not is_image_file(path) then
    return {}, 0
  end

  local dir = vim.fs.dirname(path)
  local files = {}
  local normalized_path = vim.fs.normalize(path)

  for name, kind in vim.fs.dir(dir) do
    if kind == "file" then
      local sibling = vim.fs.joinpath(dir, name)
      if is_image_file(sibling) then
        files[#files + 1] = vim.fs.normalize(sibling)
      end
    end
  end

  table.sort(files)

  local index = 0
  for i, sibling in ipairs(files) do
    if sibling == normalized_path then
      index = i
      break
    end
  end

  return files, index
end

local function set_image_browser_state(path)
  local files, index = collect_image_siblings(path)
  image_browser = {
    path = path,
    dir = path and vim.fs.dirname(path) or nil,
    files = files,
    index = index,
  }
end

local function resolve_image_path(cb)
  local neo_tree_path = neo_tree_selected_path()
  if neo_tree_path then
    local resolved = resolve_candidate(neo_tree_path)
    if resolved then
      return cb(resolved)
    end
  end

  local path = vim.api.nvim_buf_get_name(0)
  local resolved = resolve_candidate(path)
  if resolved then
    return cb(resolved)
  end

  local candidates = {
    vim.fn.expand("<cfile>"),
    vim.fn.expand("<cWORD>"),
  }

  local line = vim.api.nvim_get_current_line()
  for token in line:gmatch("%S+") do
    candidates[#candidates + 1] = trim_path_token(token)
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_col = math.max(1, cursor[2] - 80)
  local end_col = math.min(#line, cursor[2] + 80)
  local snippet = line:sub(start_col, end_col)
  for token in snippet:gmatch("%S+") do
    candidates[#candidates + 1] = trim_path_token(token)
  end

  for _, candidate in ipairs(candidates) do
    resolved = resolve_candidate(candidate)
    if resolved then
      return cb(resolved)
    end
  end

  if Snacks and Snacks.image and Snacks.image.doc then
    Snacks.image.doc.at_cursor(function(src)
      if not src or src == "" then
        return cb(nil)
      end

      resolved = resolve_candidate(src)
      if resolved then
        return cb(resolved)
      end

      cb(nil)
    end)
    return
  end

  cb(nil)
end

local function close_viewer()
  if hover_win and hover_win.close then
    pcall(function()
      hover_win:close({ buf = true })
    end)
  end
  hover_win = nil
end

local function open_float_image(path)
  close_viewer()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, path)
  vim.bo[buf].swapfile = false
  vim.bo[buf].bufhidden = "wipe"

  local win = Snacks.win({
    buf = buf,
    show = false,
    enter = false,
    relative = "editor",
    position = "float",
    width = 0.9,
    height = 0.9,
    border = true,
    backdrop = false,
    minimal = true,
    wo = {
      wrap = false,
      number = false,
      relativenumber = false,
      signcolumn = "no",
      foldcolumn = "0",
      list = false,
      spell = false,
      statuscolumn = "",
      cursorline = false,
      cursorcolumn = false,
    },
    bo = {
      swapfile = false,
      bufhidden = "wipe",
    },
  })

  win:open_buf()
  Snacks.image.buf.attach(buf, { src = path })
  win:show()
  vim.cmd("redraw")
  hover_win = win
end

local function open_full_image(path)
  vim.cmd("tabedit " .. vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  Snacks.image.buf.attach(buf, { src = path })
  vim.cmd("redraw")
end

local function reload_current_image()
  local buf = vim.api.nvim_get_current_buf()
  local path = resolve_candidate(vim.api.nvim_buf_get_name(buf))

  if not path then
    notify_no_image("Current buffer is not an image file")
    return
  end

  Snacks.image.placement.clean(buf)
  Snacks.image.buf.attach(buf, { src = path })
  vim.cmd("redraw")
end

local function open_image_under_cursor()
  resolve_image_path(function(path)
    if not path then
      notify_no_image()
      return
    end

    open_float_image(path)
  end)
end

local function open_adjacent_image(step)
  local state = image_browser
  local path = state.path

  if not path or path == "" then
    resolve_image_path(function(resolved)
      if not resolved then
        notify_no_image()
        return
      end

      set_image_browser_state(resolved)
      open_full_image(resolved)
    end)
    return
  end

  if not state.files or #state.files == 0 then
    set_image_browser_state(path)
    state = image_browser
  end

  if not state.files or #state.files == 0 then
    notify_no_image("No neighboring image files were found")
    return
  end

  local next_index = state.index + step
  if next_index < 1 then
    next_index = #state.files
  elseif next_index > #state.files then
    next_index = 1
  end

  local next_path = state.files[next_index]
  set_image_browser_state(next_path)
  open_full_image(next_path)
end

vim.keymap.set("n", "Ih", open_image_under_cursor, { desc = "Image hover" })
vim.keymap.set("n", "If", function()
  resolve_image_path(function(path)
    if not path then
      notify_no_image()
      return
    end

    set_image_browser_state(path)
    open_full_image(path)
  end)
end, { desc = "Image fullscreen" })
vim.keymap.set("n", "<leader>ih", open_image_under_cursor, { desc = "Image hover" })
vim.keymap.set("n", "<leader>if", function()
  resolve_image_path(function(path)
    if not path then
      notify_no_image()
      return
    end

    set_image_browser_state(path)
    open_full_image(path)
  end)
end, { desc = "Image fullscreen" })
vim.keymap.set("n", "<leader>in", function()
  open_adjacent_image(1)
end, { desc = "Next image" })
vim.keymap.set("n", "<leader>ip", function()
  open_adjacent_image(-1)
end, { desc = "Previous image" })
vim.keymap.set("n", "<leader>ic", close_viewer, { desc = "Close image preview" })
vim.keymap.set("n", "<leader>ir", reload_current_image, { desc = "Reload image" })

vim.api.nvim_create_user_command("ImageHover", open_image_under_cursor, {})
vim.api.nvim_create_user_command("ImageNext", function()
  open_adjacent_image(1)
end, {})
vim.api.nvim_create_user_command("ImagePrev", function()
  open_adjacent_image(-1)
end, {})
vim.api.nvim_create_user_command("ImageClose", close_viewer, {})
vim.api.nvim_create_user_command("ImageReload", reload_current_image, {})
vim.api.nvim_create_user_command("ImageFull", function()
  resolve_image_path(function(path)
    if not path then
      notify_no_image()
      return
    end

    set_image_browser_state(path)
    open_full_image(path)
  end)
end, {})

local app_by_ext = {
  bmp = "/System/Applications/Preview.app",
  gif = "/System/Applications/Preview.app",
  heic = "/System/Applications/Preview.app",
  jpeg = "/System/Applications/Preview.app",
  jpg = "/System/Applications/Preview.app",
  png = "/System/Applications/Preview.app",
  tiff = "/System/Applications/Preview.app",
  tif = "/System/Applications/Preview.app",
  webp = "/System/Applications/Preview.app",
  ply = { kind = "meshlab" },
  stl = { kind = "meshlab" },
}

local function resolve_generic_path()
  local neo_tree_path = neo_tree_selected_path()
  if neo_tree_path then
    return neo_tree_path
  end

  local candidates = { vim.fn.expand("<cfile>"), vim.fn.expand("<cWORD>") }
  local line = vim.api.nvim_get_current_line()

  for token in line:gmatch("%S+") do
    candidates[#candidates + 1] = trim_path_token(token)
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local start_col = math.max(1, cursor[2] - 80)
  local end_col = math.min(#line, cursor[2] + 80)
  local snippet = line:sub(start_col, end_col)
  for token in snippet:gmatch("%S+") do
    candidates[#candidates + 1] = trim_path_token(token)
  end

  for _, candidate in ipairs(candidates) do
    local resolved = resolve_candidate(candidate)
    if resolved then
      return resolved
    end
  end

  local path = vim.api.nvim_buf_get_name(0)
  return resolve_candidate(path)
end

local function open_in_cloudcompare(path)
  vim.fn.jobstart({ "open", "-a", "CloudCompare", path }, { detach = true })
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

local function open_parent_in_finder(path)
  local target = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  vim.fn.jobstart({ "open", target }, { detach = true })
end

local function open_current_in_app()
  local path = resolve_generic_path()
  if not path then
    vim.notify("No file found to open", vim.log.levels.INFO, { title = "Open" })
    return
  end

  open_in_app(path)
end

local function open_current_in_cloudcompare()
  local path = resolve_generic_path()
  if not path then
    vim.notify("No file found to open in CloudCompare", vim.log.levels.INFO, { title = "CloudCompare" })
    return
  end

  open_in_cloudcompare(path)
end

local function open_current_in_finder()
  local path = resolve_generic_path()
  if not path then
    vim.notify("No file found to reveal", vim.log.levels.INFO, { title = "Finder" })
    return
  end

  open_parent_in_finder(path)
end

vim.keymap.set("n", "O", open_current_in_app, { desc = "Open in app" })
vim.keymap.set("n", "<S-o>", open_current_in_app, { desc = "Open in app" })
vim.keymap.set("n", "<leader>oc", open_current_in_cloudcompare, { desc = "Open in CloudCompare" })
vim.keymap.set("n", "<leader>fo", open_current_in_finder, { desc = "Open folder in Finder" })

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit insert mode" })
