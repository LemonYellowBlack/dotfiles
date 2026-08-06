vim.loader.enable()

-- Options
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.scrolloff = 8
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.timeoutlen = 500
vim.opt.undofile = true       -- persistent undo across sessions
vim.opt.updatetime = 250      -- snappier CursorHold / diagnostics / gitsigns
vim.opt.splitright = true     -- vertical splits open to the right
vim.opt.splitbelow = true     -- horizontal splits open below
vim.opt.confirm = true        -- prompt to save instead of erroring on :q
vim.opt.autoread = true       -- reloads buffer when a file changes externally

-- General editor keymaps
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Treesitter post-install hook: compile parsers after install/update
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "nvim-treesitter" then
      if not ev.data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      vim.cmd("TSUpdate")
    end
  end,
})

-- blink.cmp build hook: compile fuzzy matcher after install/update
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "blink.cmp"
      and (ev.data.kind == "install" or ev.data.kind == "update") then
      vim.system({ "cargo", "build", "--release" }, { cwd = ev.data.path })
    end
  end,
})

-- Plugins
vim.pack.add({
  "https://github.com/rebelot/kanagawa.nvim",
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/neovim/nvim-lspconfig",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-telescope/telescope.nvim",
  "https://github.com/stevearc/oil.nvim",
  "https://github.com/nvim-tree/nvim-web-devicons",
  "https://github.com/OXY2DEV/markview.nvim",
  "https://github.com/Saghen/blink.cmp",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/echasnovski/mini.nvim",
  "https://github.com/akinsho/toggleterm.nvim",
})

----------------------------------------------------------------------
-- Kanagawa
----------------------------------------------------------------------
require("kanagawa").setup({
  theme = "wave",
  background = { dark = "wave", light = "lotus" },
  transparent = true,
})
vim.cmd.colorscheme("kanagawa")

-- Make gutter and status areas transparent to match Kitty background
local transparent_groups = {
  "Normal", "NormalNC", "NormalFloat",
  "SignColumn", "LineNr", "CursorLineNr",
  "StatusLine", "StatusLineNC",
  "TabLine", "TabLineFill",
}
for _, group in ipairs(transparent_groups) do
  local hl = vim.api.nvim_get_hl(0, { name = group })
  hl.bg = nil
  hl.ctermbg = nil
  vim.api.nvim_set_hl(0, group, hl)
end

----------------------------------------------------------------------
-- Treesitter — parsers only; the highlight engine is built into 0.12,
-- but nvim does NOT auto-start it for non-bundled parsers, so start it
-- per-filetype below.
-- Install parsers: :TSInstall odin go lua markdown yaml json bash
----------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "odin", "go", "c", "cpp", "lua", "markdown", "yaml", "json", "bash", "python", "toml", "sql", "dockerfile" },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})


----------------------------------------------------------------------
-- Spell — prose filetypes only.
-- 'spell' is window-local and 'spelllang'/'spellfile'/'spelloptions' are
-- buffer-local, so all four must be set per-buffer here rather than globally.
--
-- 'spellfile' is a LIST and the zg count picks the target:
--   zg  -> project dictionary  (<project>/.spell/en.utf-8.add, committed)
--   2zg -> personal global     (~/.local/share/nvim/site/spell/en.utf-8.add)
-- Project first, because inside a lore repo "this is canon" is the common case.
--
-- The project entry is found by walking up from the buffer for a .spell/ dir,
-- so any repo gets a private dictionary just by creating one. Anchored to the
-- buffer, not getcwd(), so it survives :cd and subdirectory launches.
----------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "gitcommit", "text" },
  callback = function(ev)
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.spelloptions = "camel"

    local global = vim.fn.stdpath("data") .. "/site/spell/en.utf-8.add"
    local root = vim.fs.root(ev.buf, ".spell")
    if root then
      vim.opt_local.spellfile = { root .. "/.spell/en.utf-8.add", global }
    else
      vim.opt_local.spellfile = global
    end
  end,
})

----------------------------------------------------------------------
-- LSP
----------------------------------------------------------------------
vim.lsp.config("gopls", {})
vim.lsp.config("clangd", {})
-- ols config (cmd/filetypes/root_dir) ships in nvim-lspconfig's lsp/ols.lua.
-- Add init_options here if you want strict checking or custom collections:
--   vim.lsp.config("ols", { init_options = { checker_args = "-strict-style" } })

-- Python: basedpyright for types/hover/completion, ruff for lint/format.
-- Both cmd/filetypes/root_markers ship in nvim-lspconfig's lsp/*.lua.
-- basedpyright auto-detects the project's .venv (uv), so imports like
-- `anthropic` and `pydantic` resolve. Defers import-sorting to ruff.
vim.lsp.config("basedpyright", {
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "standard",   -- default "recommended" is very noisy
        diagnosticMode = "openFilesOnly",
      },
      disableOrganizeImports = true,     -- ruff owns import sorting
    },
  },
})
-- basedpyright does not format, so ruff is what the BufWritePre format-on-save
-- uses for Python.
vim.lsp.config("ruff", {})

vim.lsp.enable({ "gopls", "clangd", "ols", "basedpyright", "ruff", "marksman" })

-- Diagnostics: keep underline + gutter signs (0.11 defaults) but disable inline
-- virtual_text, which doesn't wrap and runs off-screen for long messages.
-- Read the full message on the current line via <leader>e (open_float, below).
vim.diagnostic.config({
  virtual_text = false,
  severity_sort = true,
  float = { border = "rounded", source = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local opts = { buffer = ev.buf }
    -- Built-in 0.11 defaults cover the rest: grr (references), grn (rename),
    -- gra (code action), gri (implementation), K (hover), [d/]d (diagnostics),
    -- gO (document symbols), CTRL-S (signature help, insert mode).
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)

    -- Toggle inlay hints (parameter/type hints)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
      vim.keymap.set("n", "<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
      end, opts)
    end

    -- Format on save
    if client and client:supports_method("textDocument/formatting") then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = ev.buf,
        callback = function()
          vim.lsp.buf.format({ bufnr = ev.buf })
        end,
      })
    end
  end,
})

----------------------------------------------------------------------
-- Telescope
----------------------------------------------------------------------
local telescope = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", telescope.find_files, {})
vim.keymap.set("n", "<leader>fg", telescope.live_grep, {})
vim.keymap.set("n", "<leader>fb", telescope.buffers, {})
vim.keymap.set("n", "<leader>fs", telescope.lsp_document_symbols, {})
vim.keymap.set("n", "<leader>fS", telescope.lsp_workspace_symbols, {})
vim.keymap.set("n", "<leader>fd", telescope.diagnostics, {})

----------------------------------------------------------------------
-- Oil
----------------------------------------------------------------------
require("oil").setup({
  view_options = {
    show_hidden = true,
  },
})
vim.keymap.set("n", "-", "<cmd>Oil<cr>", {})

----------------------------------------------------------------------
-- blink.cmp
----------------------------------------------------------------------
require("blink.cmp").setup({
  keymap = {
    preset = "default",
    ["<CR>"] = {},
  },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  completion = {
    list = {
      selection = { preselect = true, auto_insert = false },
    },
  },
})

----------------------------------------------------------------------
-- Markview — markdown / latex / inline-html / yaml-frontmatter previewer.
-- Deliberately NOT lazy-loaded and placed after the colorscheme, per upstream:
-- it reads highlight groups at setup time to derive its own.
--
-- LaTeX math and inline HTML need their own parsers (:TSInstall latex html).
-- They're injected parsers, so markdown's injection queries pick them up
-- automatically once the .so exists — no FileType entry needed above.
--
-- Upstream recommends 'nowrap'; we keep global wrap = true for prose notes.
-- Wrap support is limited to quotes/callouts/lists, so long wrapped lines may
-- render imperfectly. :Markview HybridToggle narrows the un-rendered region to
-- the cursor's node instead of blanking the buffer while typing.
----------------------------------------------------------------------
require("markview").setup({})

----------------------------------------------------------------------
-- Gitsigns — gutter signs, hunk staging/preview, inline blame
----------------------------------------------------------------------
require("gitsigns").setup({
  on_attach = function(bufnr)
    local gs = require("gitsigns")
    local function map(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
    end
    map("n", "]c", function() gs.nav_hunk("next") end, "Next hunk")
    map("n", "[c", function() gs.nav_hunk("prev") end, "Prev hunk")
    map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
    map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
    map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
    map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>hd", gs.diffthis, "Diff against index")
  end,
})

----------------------------------------------------------------------
-- mini.nvim — statusline, autopairs, surround
----------------------------------------------------------------------
require("mini.statusline").setup({ use_icons = true })
require("mini.pairs").setup({})
require("mini.surround").setup({})

----------------------------------------------------------------------
-- toggleterm — floating terminal
----------------------------------------------------------------------
require("toggleterm").setup({
  open_mapping = [[<c-\>]],        -- Ctrl-\ toggles the float from anywhere
  direction = "float",
  float_opts = { border = "curved" },
})

-- Float terminal opened at the CURRENT FILE's directory
local Terminal = require("toggleterm.terminal").Terminal
vim.keymap.set("n", "<leader>tt", function()
  Terminal:new({ dir = vim.fn.expand("%:p:h"), direction = "float" }):toggle()
end, { desc = "Float terminal at file dir" })

-- Lazygit in a float, scoped to the current file's git repo root
local lazygit = Terminal:new({
  cmd = "lazygit",
  dir = "git_dir",                 -- toggleterm-special: resolves to the repo root
  direction = "float",
  float_opts = { border = "curved" },
})
vim.keymap.set("n", "<leader>gg", function() lazygit:toggle() end,
  { desc = "Lazygit" })

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
