local M = {}

local grepprg = nil

------------------------------------------------------------
-- オプションの有効/無効判定
------------------------------------------------------------
local function is_enable(options, v)
	local a, b = string.find(options, v)
	return a == nil and 0 or 1
end

------------------------------------------------------------
-- make vimgrep command
------------------------------------------------------------
function make_vimgrep_cmd(search_pattern, start_directory, filter, option)
	local pattern = vim.fn.escape(search_pattern, '.^$*[]~\\(){}+?')

	local cmd = "grep! "
	-- Word Search
	cmd = cmd .. (is_enable(option, "W") == 1 and "/\\<" .. pattern or "/" .. pattern)
	-- Case-senstive
	cmd = cmd .. (is_enable(option, "C") == 1 and "\\C" or "\\c")
	-- Word Search
	cmd = cmd .. (is_enable(option, "W") == 1 and "\\>/j " or "/j ")
	-- Start search directory
	cmd = cmd .. start_directory
	-- File filter
	cmd = cmd .. "/ **/*." .. filter:gsub(",", " **/*.")

	return cmd
end

------------------------------------------------------------
-- make grep command
------------------------------------------------------------
local function make_grep_cmd(search_pattern, start_directory, filter, option)
	local o = ""
	-- Word Search
	o = o .. (is_enable(option, "W") == 1 and " -w" or "")
	-- Case-senstive
	o = o .. (is_enable(option, "C") == 1 and " -F" or " -i")

	-- Filter
	local f = ""
	if filter:find(",") then
		f = " --include={*." .. filter:gsub(",", ",*.") .. "}"
	elseif filter ~= "*" then
		f = " --include=" .. vim.fn.shellescape("*." .. filter)
	end

	local p = vim.fn.shellescape(search_pattern)
	local d = vim.fn.shellescape(start_directory)

	return "grep! " .. o .. f .. " -- " .. p .. " " .. d
end

------------------------------------------------------------
-- make grep git command
------------------------------------------------------------
local function make_gitgrep_cmd(search_pattern, start_directory, filter, option)
	local o = ""
	-- Word Search
	o = o .. (is_enable(option, "W") == 1 and " -w" or "")
	-- Case-senstive
	o = o .. (is_enable(option, "C") == 1 and " -F" or " -i")

	-- Filter
	local f = ""
	if filter ~= "*" then
		local sep = vim.loop.os_uname().sysname == "Windows_NT" and "\\" or "/"
		for ext in filter:gmatch("[^,]+") do
			f = f .. " " .. start_directory .. sep .. "*." .. ext
		end
	else
		f = " " .. start_directory
	end
	f = f ~= "" and " -- " .. f or f

	local p = vim.fn.shellescape(search_pattern)
	return "grep! " .. o .. " " .. p .. f
end

------------------------------------------------------------
-- make ripgrep command
------------------------------------------------------------
local function make_ripgrep_cmd(search_pattern, start_directory, filter, option)
	local o = ""
	-- Word Search
	o = o .. (is_enable(option, "W") == 1 and " -w" or "")
	-- Case-senstive
	o = o .. (is_enable(option, "C") == 1 and "" or " -i")
	-- Disable Regular expressions
	o = o .. (is_enable(option, "R") == 1 and " -F" or "")
	-- Encording(sjis/utf-8)
	o = o .. (is_enable(option, "E") == 1 and " -E sjis" or " -E utf8")

	local p	= vim.fn.shellescape(search_pattern)
	local f	= vim.fn.shellescape("*.{" .. filter .. "}")
	local d	= vim.fn.shellescape(start_directory)

	return "grep! " .. o .. " -g " .. f .. " -e " .. p .. " " .. d
end

------------------------------------------------------------
-- Set grepprg
------------------------------------------------------------
function M.set_grepprg(prg)
	if prg == "grep" then
		grepprg = prg
		vim.o.grepprg = "grep -nHR --binary-files=without-match"
		-- -n : 行番号を表示
		-- -H : ファイル名を表示
		-- -R : 指定ディレクトリ以下を再帰的に検索
		-- -F-: 検索語を正規表現ではなく、ただの文字列として扱う
		-- --binary-files=without-match : バイナリファイルを検索対象から除外する
		vim.o.grepformat = "%f:%l:%m"

	elseif prg == "gitgrep" then
		grepprg = prg
		vim.o.grepprg = "git grep -nI --no-color"
		-- -n : 行番号を表示
		-- -I : バイナリファイルを除外する
		-- -F-: 検索語を正規表現ではなく、ただの文字列として扱う
		-- ---no-color : 出力の色付けを無効にする
		-- --full-name : カレントディレクトリではなく、Gitリポジトリのルートからの相対パスでファイル名を表示する
		vim.o.grepformat = "%f:%l:%m"

	elseif prg == "ripgrep" then
		grepprg = prg
		vim.o.grepprg = "rg --vimgrep --hidden"
		vim.o.grepformat = "%f:%l:%m"

	else
		grepprg = "internal"
		vim.o.grepprg = "internal"
		vim.o.grepformat = "%f:%l:%m,%f:%l%m,%f  %l%m"
	end
end

----------------------------------------------------------------
-- setup
----------------------------------------------------------------
function M.make_grepcmd(search_pattern, start_directory, filter, option)
	local func = nil
	if grepprg == "grep" then
		func = make_grep_cmd
	elseif grepprg == "gitgrep" then
		func = make_gitgrep_cmd
	elseif grepprg == "ripgrep" then
		func = make_ripgrep_cmd
	else
		func = make_vimgrep_cmd
	end

	return func(search_pattern, start_directory, filter, option)
end

return M

