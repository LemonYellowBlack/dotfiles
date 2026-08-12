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
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/windwp/nvim-ts-autotag",
  "https://github.com/brenoprata10/nvim-highlight-colors",
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
-- Web stack:       :TSInstall tsx typescript javascript css html
-- Note: .tsx uses the `tsx` parser, .jsx uses the `javascript` parser.
----------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "odin", "go", "c", "cpp", "lua", "markdown", "yaml", "json", "bash",
    "python", "toml", "sql", "dockerfile", "java",
    "javascript", "javascriptreact", "typescript", "typescriptreact",
    "css", "scss", "html",
  },
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

----------------------------------------------------------------------
-- Web filetypes use 2-space indent (Prettier's default). The global
-- shiftwidth of 4 would otherwise fight format-on-save on every write.
----------------------------------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "javascript", "javascriptreact", "typescript", "typescriptreact",
    "json", "jsonc", "css", "scss", "html", "yaml",
  },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
  end,
})


----------------------------------------------------------------------
-- Spell
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

-- TypeScript / React ------------------------------------------------
-- Inlay hints are OFF at the server level by default; enabling
-- vim.lsp.inlay_hint client-side (see LspAttach below) is not enough.
local ts_inlay_hints = {
  parameterNames           = { enabled = "literals" },
  parameterTypes           = { enabled = true },
  variableTypes            = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes  = { enabled = true },
  enumMemberValues         = { enabled = true },
}

local ts_settings = {
  typescript = {
    inlayHints = ts_inlay_hints,
    -- Renaming a file in Oil rewrites every import that referenced it.
    updateImportsOnFileMove = { enabled = "always" },
  },
  javascript = {
    inlayHints = ts_inlay_hints,
    updateImportsOnFileMove = { enabled = "always" },
  },
}

vim.lsp.config("vtsls", { settings = ts_settings })
vim.lsp.config("ts_ls", { settings = ts_settings })

-- eslint owns the React-specific diagnostics TypeScript cannot see:
-- react-hooks/exhaustive-deps and conditional hook calls.
vim.lsp.config("eslint", {
  settings = { workingDirectories = { mode = "auto" } },
})

vim.lsp.config("tailwindcss", {})

local servers = { "gopls", "clangd", "ols", "basedpyright", "ruff", "marksman", "jdtls" }

-- Web servers are enabled only when their binary is actually on PATH, so a
-- missing install is a no-op rather than a silent failed attach. vtsls wins
-- over ts_ls when both are present; enabling both would double-attach.
local web_servers = {
  vtsls       = "vtsls",
  ts_ls       = "typescript-language-server",
  eslint      = "vscode-eslint-language-server",
  tailwindcss = "tailwindcss-language-server",
}
for server, binary in pairs(web_servers) do
  if vim.fn.executable(binary) == 1 then
    if not (server == "ts_ls" and vim.fn.executable("vtsls") == 1) then
      table.insert(servers, server)
    end
  end
end

vim.lsp.enable(servers)

vim.diagnostic.config({
  virtual_text = false,
  severity_sort = true,
  float = { border = "rounded", source = true },
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local opts = { buffer = ev.buf }
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

    -- Format on save. These clients advertise textDocument/formatting but
    -- must not use it: the TypeScript servers ship the old VSCode JS
    -- formatter, which silently fights Prettier and churns every diff.
    -- conform.nvim owns formatting for all of them instead.
    local skip_lsp_format = {
      vtsls = true, ts_ls = true, eslint = true,
      jsonls = true, html = true, cssls = true, tailwindcss = true,
    }
    if client
      and client:supports_method("textDocument/formatting")
      and not skip_lsp_format[client.name] then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = ev.buf,
        callback = function()
          vim.lsp.buf.format({ bufnr = ev.buf })
        end,
      })
    end

    -- Apply eslint autofixes on save (import order, hook deps, etc.)
    if client and client.name == "eslint" then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = ev.buf,
        callback = function()
          pcall(vim.cmd, "LspEslintFixAll")
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
-- conform.nvim — Prettier-based formatting for the web stack.
-- Preferred over LSP formatting because it honours the project's own
-- .prettierrc and degrades gracefully when a project has none.
-- prettierd is a warm daemon (~15ms); prettier is the fallback.
----------------------------------------------------------------------
local prettier = { "prettierd", "prettier", stop_after_first = true }

require("conform").setup({
  formatters_by_ft = {
    javascript      = prettier,
    javascriptreact = prettier,
    typescript      = prettier,
    typescriptreact = prettier,
    css             = prettier,
    scss            = prettier,
    html            = prettier,
    json            = prettier,
    jsonc           = prettier,
  },
  format_on_save = {
    timeout_ms = 1000,
    lsp_format = "never",   -- LSP formatting is handled in LspAttach
  },
})

----------------------------------------------------------------------
-- nvim-ts-autotag — close and rename JSX/HTML tag pairs.
-- mini.pairs handles brackets and quotes but has no concept of tags.
----------------------------------------------------------------------
require("nvim-ts-autotag").setup()

----------------------------------------------------------------------
-- nvim-highlight-colors — inline swatches for hex/rgb and Tailwind classes
----------------------------------------------------------------------
require("nvim-highlight-colors").setup({
  render = "virtual",
  virtual_symbol = "●",
  enable_tailwind = true,
})

----------------------------------------------------------------------
-- toggleterm — floating terminal
----------------------------------------------------------------------
require("toggleterm").setup({
  open_mapping = [[<c-\>]],        
  direction = "float",
  float_opts = { border = "curved" },
  highlights = {
    FloatBorder = { guifg = "#727169"},
  },
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

----------------------------------------------------------------------
-- Plugin pruning — KEEP THIS LAST
--
-- Uninstalls plugins that are still on disk but no longer listed in
-- vim.pack.add(), so deleting a line from that list is the whole uninstall
-- procedure and nvim-pack-lock.json doesn't resurrect them on every machine.
--
-- This must stay below every vim.pack.add() call in the config. A plugin that
-- hasn't been added yet this session looks stale, so a prune running above an
-- add() would delete and re-clone that plugin on every startup.
----------------------------------------------------------------------
local stale = vim.iter(vim.pack.get())
  :filter(function(p) return not p.active end)
  :map(function(p) return p.spec.name end)
  :totable()
if #stale > 0 then
  vim.pack.del(stale)
end
