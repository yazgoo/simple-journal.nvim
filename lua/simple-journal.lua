local api = vim.api

local function hash_color(tag)
  local cterm_palette = {
	"b0ffb6",
	"c6fd8a",
  "ffe4b5",
	"82fdd3",
	"e883f8",
	"ffb3b3",
  "dab6fc",
	"995449",
  "d4a5a5",
  "b3e5fc",
  "aef1ef",
  "b2f2bb",
  "c8f7c5",
	"bbffff",
	"ffc5a6",
  "ffdab9",
	"ffdf90",
  "ffd1dc",
  }
  local index = 0
  for i = 1, #tag do
    index = index + string.byte(tag:sub(i, i))
  end
  index = index % #cterm_palette
  return cterm_palette[index + 1]
end

local function highlight_hashtags(bufnr, ns_id, line, line_num)
  for start_pos, tag, end_pos in line:gmatch("()#(%w+)()") do
    local hue = hash_color(tag)
    local group = "HashtagColor" .. hue
    local highlight_cmd = string.format("highlight %s guifg=#%s", group, hue)
    vim.cmd(highlight_cmd)
    api.nvim_buf_add_highlight(bufnr, ns_id, group, line_num - 1, start_pos - 1, end_pos - 1)
  end
end

local function highlight_links(bufnr, ns_id, line, line_num)
  for start_pos, tag, end_pos in line:gmatch("()%[%[(.-)%]%]()") do
    api.nvim_buf_add_highlight(bufnr, ns_id, "SpecialChar", line_num - 1, start_pos - 1, end_pos - 1)
  end
end

local function apply_sjournal_highlights(bufnr)
  local sjournal_patterns = {
    { pattern = "todo", symbol = "-", hl = "Function" },
    { pattern = "event", symbol = "o", hl = "SpecialKey" },
    { pattern = "note", symbol = "n", hl = "String" },
    { pattern = "done", symbol = "x", hl = "Comment" },
    { pattern = "waiting", symbol = "w", hl = "Boolean" },
    { pattern = "week", symbol = "week", hl = "Underlined" },
  }
  local ns_id = api.nvim_create_namespace('sjournal_highlighter')
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for line_num, line in ipairs(lines) do
    for _, pat in ipairs(sjournal_patterns) do
      if line:find("^ *" .. pat.pattern .. " ") or  line:find("^ *" .. pat.symbol .. " ") then
        line = line:gsub(pat.pattern, pat.symbol)
        api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, { line })
        api.nvim_buf_add_highlight(bufnr, ns_id, pat.hl, line_num - 1, 0, -1)
        highlight_hashtags(bufnr, ns_id, line, line_num)
        highlight_links(bufnr, ns_id, line, line_num)
      end
    end
  end
end

api.nvim_create_autocmd("FileType", {
  pattern = "sjournal",
  callback = function()
    vim.opt_local.foldmethod = 'indent'
    vim.opt_local.foldenable = true
    vim.cmd('highlight Folded guibg=NONE guifg=grey')
  end,
})

local when_ft = { "BufRead", "BufNewFile"}
for _, event in ipairs(when_ft) do
  api.nvim_create_autocmd("BufNewFile", {
      pattern = "*.sjournal",
      command = "set filetype=sjournal"
    })
end

local when_apply = { "BufRead", "BufNewFile", "BufWritePost", "TextChanged" , "TextChangedI", "TextChangedP" }
for _, event in ipairs(when_apply) do
  api.nvim_create_autocmd(event, {
    pattern = "*.sjournal",
    callback = function()
      local bufnr = api.nvim_get_current_buf()
      apply_sjournal_highlights(bufnr)
    end,
  })
end

local function create_sjournal_file()
  local year = os.date('%Y')
  local month = os.date('%m')
  local filename = string.format('%s/%s.sjournal', year, month)
  local full_path = vim.fn.expand('%:p:h') .. '/' .. filename
  vim.fn.mkdir(year, 'p')
  if vim.fn.filereadable(full_path) == 1 then
    api.nvim_err_writeln('Error: File ' .. full_path .. ' already exists!')
    return
  end
  vim.cmd('edit ' .. full_path)
  local nc_result = vim.fn.system('cal')
  local file = io.open(full_path, 'w')
  if file then
    file:write(nc_result .. '\n\n')
    file:write('week 1\n')
    file:write(os.date('%A') .. '\n')
    file:close()
  end
end

local function run_sjournal_action()
  local line = api.nvim_get_current_line()
  local col = api.nvim_win_get_cursor(0)[2]
  local current_buf_path = api.nvim_buf_get_name(0)
  local current_dir = vim.fn.fnamemodify(current_buf_path, ":h")
  for start_pos, tag, end_pos in line:gmatch("()%[%[(.-)%]%]()") do
    if col >= start_pos - 1 and col <= end_pos - 1 then
      vim.cmd("edit " .. current_dir .. "/" .. tag)
      return
    end
  end
end

local function setup() 
  api.nvim_create_user_command('SJournalNew', create_sjournal_file, {})
  api.nvim_create_user_command('SJournalAction', run_sjournal_action, {})
end

return {
  setup = setup,
}
