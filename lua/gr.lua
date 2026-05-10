-- lua/gr.lua
local cmd = require('cmd.grepcmd')

local M = {}

-- ウィンドウ情報
local W = {win = nil, buf = nil}

-- 履歴の展開有無、長さ
local expand = {lnum = 0, length = 0}

-- vim grepprg
local grepprg = "internal"

-- 検索パターン(カレントと履歴)
local search_pattern = ""
local search_pattern_old = {"", "", "", "", ""}

-- 検索開始ディレクトリ(カレントと履歴)
local start_directory = ""
local start_directory_old = {}

-- 検索フィルタ
local filter = "c,cpp"

-- 検索オプション(W:Word, C:Case senstive, E:utf-8/sjis
local option = "WC"

------------------------------------------------------------
-- grepprgの切り替え
------------------------------------------------------------
local function change_grepprg()
	-- internal --> grep --? git grep --? rip grep --? internal ...
	grepprg = grepprg == "internal" and "grep" or grepprg == "grep" and "gitgrep" or grepprg == "gitgrep" and "ripgrep" or "internal"

	-- set grepprg
	cmd.set_grepprg(grepprg)

	-- タイトルを変更
	vim.api.nvim_win_set_config(W.win, { title = " (G) " .. grepprg .. " "})
end

------------------------------------------------------------
-- オプション設定状態を返却
------------------------------------------------------------
local function is_enable(v)
	local a, b = string.find(option, v)
	return a == nil and "" or "*"
end

------------------------------------------------------------
-- Toggle option
------------------------------------------------------------
local function set_option(v)
	local a, b = string.find(option, v)
	if a == nil then
		-- on
		option = option .. v
	else
		-- off
		option = option:gsub(v, "")
	end
end

----------------------------------------------------------------
-- 配列の全要素から最大の横幅を返す
----------------------------------------------------------------
local function max_width(lists)
	local max = 0
	for _, v in ipairs(lists) do
		max = math.max(max, #v)
	end

	return max
end

----------------------------------------------------------------
-- 全てのキーマップをクリア
----------------------------------------------------------------
local function clear_buffer_mappings()
--	local modes = {'n', 'v', 'i', 'x', 's', 'o', 'c', 't'}
    local modes = {'n'}

    for _, mode in ipairs(modes) do
        -- 現在のバッファの特定モードのマッピングを取得
        local mappings = vim.api.nvim_buf_get_keymap(0, mode)
        for _, mapping in ipairs(mappings) do
            -- マッピングを削除
            vim.keymap.del(mode, mapping.lhs, { buffer = 0 })
        end
    end
end

------------------------------------------------------------
-- 履歴の更新
------------------------------------------------------------
local function update_history(list, item)
    -- 重複があれば削除（一度テーブルから消して、常に先頭に入れる準備）
    for i, v in ipairs(list) do
        if v == item then
            table.remove(list, i)
            break
        end
    end

    -- 先頭に追加
    table.insert(list, 1, item)

    -- 5つを超えた分を削除
    if #list > 5 then
        table.remove(list)
    end
end

------------------------------------------------------------
-- ウィンドウ用メニューの作成
------------------------------------------------------------
local function make_menu()
	local menu = {}
	table.insert(menu, " (s) Search pattern   " .. search_pattern .. " ")
	if expand.lnum == 1 then
		for i, item in ipairs(search_pattern_old) do
			table.insert(menu, "                      " .. item .. " ")
		end
	end
	table.insert(menu, " (d) Directory        " .. start_directory .. " ")
	if expand.lnum == 2 then
		for i, item in ipairs(start_directory_old) do
			table.insert(menu, "                      " .. item .. " ")
		end
	end
	table.insert(menu, "")
	table.insert(menu, " (f) File filter      " .. filter .. " ")
	table.insert(menu, " (w) Word search      " .. is_enable("W") .. " ")
	table.insert(menu, " (c) Case senstive    " .. is_enable("C") .. " ")
	if grepprg == "ripgrep" then
		table.insert(menu, " (2) Encoding         " .. (is_enable("E") ~= 0 and "sjis" or "utf8") .. " ")
	end

	return menu
end

----------------------------------------------------------------
-- folding
----------------------------------------------------------------
local function folding()
	-- 未展開だったら何もしない
	if expand.lnum == 0 then return end

	-- カーソルを親に移動
	vim.api.nvim_win_set_cursor(0, {expand.lnum, 0})

	-- 折り畳みoff
	expand.lnum = 0
end

----------------------------------------------------------------
-- set highlight
----------------------------------------------------------------
local function set_highlight()
	-- バッファに紐づくハイライト等を一括クリア
	vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)

	-- 一時的にオフにしてからオンに戻す
	vim.cmd('syntax off')
	vim.cmd('syntax on')

	-- ハイライト設定
	if expand.lnum == 0 then
		vim.cmd([[set winhighlight=Normal:Normal]])
		vim.api.nvim_set_hl(0, 'FloatBorder', {link = 'Normal'})
		vim.cmd([[syntax match gr_label /\v^.{1,20}/]])
		vim.api.nvim_set_hl(0, 'gr_label', {default = true, link = 'Identifier'})
	else
		vim.cmd([[syntax match gr_expand "^ (.*"]])
		vim.api.nvim_set_hl(0, 'gr_expand', {default = true, link = 'Comment'})
	end
end

----------------------------------------------------------------
-- draw_buffer
----------------------------------------------------------------
local function render_menu()
	-- make menu
	local lines = make_menu()

	-- 横幅を計算
	local width = math.min(max_width(lines), vim.o.columns - 2)

	-- ウィンドウの幅と高さを表示内容に合わせて再設定
	vim.api.nvim_win_set_width(W.win, width)
	vim.api.nvim_win_set_height(W.win, #lines)

	-- draw buffer
	vim.api.nvim_buf_set_option(W.buf, 'modifiable', true)
	vim.api.nvim_buf_set_lines(W.buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(W.buf, 'modifiable', false)

	-- set highlight
	set_highlight()
end

------------------------------------------------------------
-- Input search pattern
------------------------------------------------------------
local function input_search_pattern()
	vim.ui.input({prompt = "Search pattern: ", default = search_pattern}, function(instr)
		if instr then
			-- 改行コードを削除して更新
			search_pattern = instr:gsub("[\r\n]", "")
			render_menu()
		end
	end)
end

------------------------------------------------------------
-- Edit start directory
------------------------------------------------------------
local function edit_start_directory(cb)
	local dir = vim.fn.input("Search start directory: ", start_directory , "dir")
	if dir == nil or dir == "" then
		return
	end

	-- 改行コードを削除
	dir = dir:gsub("[\r\n]", "")

	if vim.loop.os_uname().sysname ~= "Windows_NT" then
		dir = dir:gsub("/$", "")
	else
		dir = dir:gsub("\\$", "")
	end

	if vim.fn.isdirectory(dir) == 1 then
		start_directory = vim.fn.fnamemodify(dir, ":p:h")
		render_menu()
	else
		vim.api.nvim_echo({{ "Error: Directory " .. dir .. " doesn't exist", "WarningMsg" }}, false, {})
	end
end

------------------------------------------------------------
-- 検索フィルタの入力
------------------------------------------------------------
local function input_file_filter()
	vim.ui.input({prompt = "Search in files matching pattern: ", default = filter}, function(instr)
		if instr then
			if instr == "" then
				filter = "*"
			else
				filter = instr:gsub("[\r\n]", "")
			end
			render_menu()
		end
	end)
end

----------------------------------------------------------------
-- カーソル上下移動
----------------------------------------------------------------
local function on_cursor(dir)
	local lnum = vim.fn.line(".") + (dir == "up" and -1 or 1)
	local min = expand.lnum == 0 and 1 or expand.lnum + 1
	local max = expand.lnum == 0 and vim.api.nvim_win_get_height(0) or (expand.lnum + expand.length)

	if lnum < min then
		lnum = max
	elseif lnum > max then
		lnum = min
	end

	vim.api.nvim_win_set_cursor(0, {lnum, 0})
end

----------------------------------------------------------------
-- 選択処理
----------------------------------------------------------------
local function on_select()
	local lnum = vim.fn.line(".")

	if expand.lnum == 0 then
		if lnum == 1 then		-- Search pattern
			expand.lnum = lnum
			expand.length = #search_pattern_old
			vim.api.nvim_win_set_cursor(0, {lnum + 1, 0})

		elseif lnum == 2 then	-- Start directory
			expand.lnum = lnum
			expand.length = #start_directory_old
			vim.api.nvim_win_set_cursor(0, {lnum + 1, 0})

		elseif lnum == 4 then	-- File filter
			input_file_filter()

		elseif lnum == 5 then	-- Word
			set_option("W")

		elseif lnum == 6 then	-- Case senstive
			set_option("C")

		elseif lnum == 7 then	-- Encord
			set_option("E")
		end

	else
		if lnum <= expand.lnum or lnum > expand.lnum + expand.length then
			return
		end

		local idx = lnum - expand.lnum
		if expand.lnum == 1 then
			search_pattern = search_pattern_old[idx]
		else
			start_directory = start_directory_old[idx]
		end

		vim.api.nvim_win_set_cursor(0, {expand.lnum, 0})
		expand.lnum = 0
	end
end

------------------------------------------------------------
-- Run grep
------------------------------------------------------------
local function run_grep()
	if not search_pattern or search_pattern == "" then
		return
	end

	-- Close the QuickFix and Move latest quickfix
	vim.cmd("cclose")
	local cnew_count = vim.fn.getqflist({ nr = "$" }).nr - vim.fn.getqflist({ nr = 0 }).nr
	if cnew_count > 0 then
		vim.cmd(("cnew %d"):format(cnew_count))
	end

	-- Update history
	update_history(search_pattern_old, search_pattern)
	update_history(start_directory_old, start_directory)

	-- >>> grep executing >>>.
	vim.api.nvim_echo({{">>> grep executing >>>", "Search"}}, false, {})

	-- 検索開始ディレクトリに移動
	vim.cmd("lcd " .. start_directory)

	-- make grep command
	local cmd = cmd.make_grepcmd(search_pattern, start_directory, filter, option)

	-- Run grep
	local start_time = vim.loop.hrtime()
	vim.cmd("silent! " .. cmd)
	local elapsed = (vim.loop.hrtime() - start_time) / 1e9

	-- If there is a hit as a result of the search, display the QuickFix and set it to be rewritable.
	local hits = #vim.fn.getqflist()
	if hits > 0 then
		vim.cmd("botright copen")
		vim.cmd("redraw!")
		vim.o.modifiable = true
		vim.o.wrap = false
		vim.api.nvim_echo({{("%d hits.  (%.3f sec)"):format(hits, elapsed), "None" }}, false, {})
	else
		vim.cmd("redraw!")
		vim.api.nvim_echo({{("Search pattern not found.  (%.3f sec)"):format(elapsed), "None" }}, false, {})
	end
end

------------------------------------------------------------
-- ウィンドウの終了
------------------------------------------------------------
local function close_window()
	if W.win and vim.api.nvim_win_is_valid(W.win) then
		vim.api.nvim_win_close(W.win, true)
	end
	W.win = nil
	W.buf = nil
end

------------------------------------------------------------
-- ウィンドウの作成
------------------------------------------------------------
local function open_window()
	close_window()

	-- make menu
	local lines = make_menu()

	-- create buffer
	W.buf = vim.api.nvim_create_buf(false, true)

	-- create floating window
	local width = math.min(max_width(lines), vim.o.columns - 2)
	W.win = vim.api.nvim_open_win(W.buf, true, {
						title	= " (G) " .. grepprg .. " ",
						style	= "minimal",
						relative= "editor",
						height	= #lines,
						width	= width,
						col		= math.ceil(vim.o.columns - width) * 0.5 - 1,
						row		= math.ceil(vim.o.lines - #lines) * 0.5 - 1,
						border	= "single",
					})

	-- draw buffer
	vim.api.nvim_buf_set_option(W.buf, 'modifiable', true)
	vim.api.nvim_buf_set_lines(W.buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(W.buf, 'modifiable', false)

	-- set buffer option
	vim.api.nvim_win_set_option(W.win, "cursorline", true)
	vim.api.nvim_buf_set_option(W.buf, 'bufhidden', 'delete')

	-- set highlight
	set_highlight()

	-- clear keymaps
	clear_buffer_mappings()

	-- set keymaps
	local function map(lhs, rhs)
		vim.keymap.set("n", lhs, rhs, { buffer = W.buf, nowait = true, silent = true })
	end
	map("q", function() close_window() end)
	map("g", function() close_window() run_grep() end)
	map("l", function() on_select() render_menu() end)
	map("h", function() folding() render_menu() end)
	map("G", function() change_grepprg() render_menu() end)
	map("s", function() input_search_pattern() end)
	map("d", function() edit_start_directory() end)
	map("f", function() input_file_filter() end)
	map("w", function() set_option("W") render_menu() end)
	map("c", function() set_option("C") render_menu() end)
	map("2", function() set_option("E") render_menu() end)
	map("k", function() on_cursor("up") end)
	map("j", function() on_cursor("down") end)
end

------------------------------------------------------------
-- Entry point
------------------------------------------------------------
function gr_start(arg)
	-- 検索パターンの取得
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true)
	if arg.range > 0 then
		-- 選択範囲の取得
		local _, srow, scol, _ = unpack(vim.fn.getpos("'<"))
		local _, erow, ecol, _ = unpack(vim.fn.getpos("'>"))

		-- get_textは0-indexedなので調整
		local lines = vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})

		-- 状態を強制同期
		vim.cmd('redraw')
		ptn = table.concat(lines, "\n")
	else
		ptn = vim.fn.expand("<cword>")
	end
	search_pattern = ptn:gsub("[\r\n]", "")

	-- 初期検索開始ディレクトリ
	start_directory = start_directory_old[1]

	-- grを実行したディレクトリを履歴の最後に登録
	start_directory_old[5] = vim.fn.expand("%:p:h")

	-- メニュー展開情報初期化
	expand.lnum = 0

	-- ウィンドウの作成
	open_window()
end

----------------------------------------------------------------
-- init directory
----------------------------------------------------------------
local function init_directory()
	local current_directory = vim.fn.expand("%:p:h")
	start_directory_old	= {current_directory, vim.loop.cwd(), vim.loop.cwd(), vim.loop.cwd(), current_directory}
end

----------------------------------------------------------------
-- setup_commands
----------------------------------------------------------------
local function setup_commands()
	local command = vim.api.nvim_create_user_command
	command("Gr", gr_start, {nargs = 0, range = true})
end

----------------------------------------------------------------
-- setup
----------------------------------------------------------------
function M.setup(user_conf)
	user_conf = user_conf or {}
	grepprg = user_conf.grepprg or "internal"

	init_directory()
	cmd.set_grepprg(grepprg)
	setup_commands()
end

return M

