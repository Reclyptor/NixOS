{ config, pkgs, ... }: {
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;

    # LSP servers and tool dependencies installed via Nix (not mason)
    extraPackages = with pkgs; [
      # LSP servers — add more as needed (rust-analyzer, gopls, pyright, etc.)
      lua-language-server   # Lua  (Neovim config itself)
      nil                   # Nix
      bash-language-server  # Bash / shell scripts

      # Required by Telescope
      ripgrep
      fd
    ];

    plugins = with pkgs.vimPlugins; [
      # --- Tree-sitter (syntax, indent, text-objects, sticky context) ---
      nvim-treesitter.withAllGrammars
      nvim-treesitter-textobjects
      nvim-treesitter-context

      # --- LSP ---
      nvim-lspconfig
      fidget-nvim            # LSP progress spinner

      # --- Completion ---
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp_luasnip
      luasnip
      friendly-snippets

      # --- Fuzzy picker (Helix-style space menu) ---
      plenary-nvim
      telescope-nvim
      telescope-fzf-native-nvim

      # --- Which-key (show available keybinds after leader) ---
      which-key-nvim

      # --- Git decorations ---
      gitsigns-nvim

      # --- File explorer ---
      nvim-web-devicons
      nui-nvim
      neo-tree-nvim

      # --- Status- and buffer-line ---
      lualine-nvim
      bufferline-nvim

      # --- Editing helpers ---
      nvim-surround          # ys/cs/ds surround operations
      nvim-autopairs         # auto-close brackets/quotes
      comment-nvim           # gcc/gc comment toggle
      vim-visual-multi       # multi-cursor (Ctrl-N)

      # --- Navigation ---
      flash-nvim             # jump to any position (gs)

      # --- UI ---
      indent-blankline-nvim  # indent guides with scope highlight
      trouble-nvim           # diagnostics / references panel
    ];

    initLua = ''
      -- ============================================================
      -- OPTIONS
      -- ============================================================
      local opt = vim.opt
      opt.number         = true
      opt.relativenumber = true
      opt.signcolumn     = "yes"
      opt.cursorline     = true
      opt.scrolloff      = 8
      opt.sidescrolloff  = 8
      opt.wrap           = false
      opt.expandtab      = true
      opt.shiftwidth     = 2
      opt.tabstop        = 2
      opt.smartindent    = true
      opt.ignorecase     = true
      opt.smartcase      = true
      opt.hlsearch       = true
      opt.incsearch      = true
      opt.termguicolors  = true
      opt.splitbelow     = true
      opt.splitright     = true
      opt.undofile       = true
      opt.updatetime     = 200
      opt.timeoutlen     = 300
      opt.completeopt    = { "menu", "menuone", "noselect" }
      opt.pumheight      = 10
      opt.showmode       = false   -- shown by lualine
      opt.list           = true
      opt.listchars      = { tab = "» ", trail = "·", nbsp = "␣" }

      -- ============================================================
      -- TREESITTER
      -- Provides: syntax highlighting, smart indentation, structural
      -- text-objects (functions/classes/params), and sticky context.
      -- nvim-treesitter 0.10+ dropped the `configs` module; highlight
      -- and indent are now enabled via Neovim's built-in treesitter API.
      -- ============================================================
      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          local ok = pcall(vim.treesitter.start)
          if ok then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Textobjects: global options (keymaps are set manually below)
      local ts_sel  = require("nvim-treesitter-textobjects.select")
      local ts_move = require("nvim-treesitter-textobjects.move")
      local ts_swap = require("nvim-treesitter-textobjects.swap")
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move   = { set_jumps = true },
      })

      -- Text-object keymaps (x = visual, o = operator-pending)
      local xo = { "x", "o" }
      vim.keymap.set(xo, "af", function() ts_sel.select_textobject("@function.outer") end,  { desc = "TS: outer function" })
      vim.keymap.set(xo, "if", function() ts_sel.select_textobject("@function.inner") end,  { desc = "TS: inner function" })
      vim.keymap.set(xo, "ac", function() ts_sel.select_textobject("@class.outer") end,     { desc = "TS: outer class" })
      vim.keymap.set(xo, "ic", function() ts_sel.select_textobject("@class.inner") end,     { desc = "TS: inner class" })
      vim.keymap.set(xo, "aa", function() ts_sel.select_textobject("@parameter.outer") end, { desc = "TS: outer param" })
      vim.keymap.set(xo, "ia", function() ts_sel.select_textobject("@parameter.inner") end, { desc = "TS: inner param" })
      vim.keymap.set(xo, "ab", function() ts_sel.select_textobject("@block.outer") end,     { desc = "TS: outer block" })
      vim.keymap.set(xo, "ib", function() ts_sel.select_textobject("@block.inner") end,     { desc = "TS: inner block" })

      -- Movement keymaps
      vim.keymap.set("n", "]f", function() ts_move.goto_next_start("@function.outer") end,     { desc = "TS: Next func start" })
      vim.keymap.set("n", "]c", function() ts_move.goto_next_start("@class.outer") end,        { desc = "TS: Next class start" })
      vim.keymap.set("n", "]F", function() ts_move.goto_next_end("@function.outer") end,       { desc = "TS: Next func end" })
      vim.keymap.set("n", "]C", function() ts_move.goto_next_end("@class.outer") end,          { desc = "TS: Next class end" })
      vim.keymap.set("n", "[f", function() ts_move.goto_previous_start("@function.outer") end, { desc = "TS: Prev func start" })
      vim.keymap.set("n", "[c", function() ts_move.goto_previous_start("@class.outer") end,    { desc = "TS: Prev class start" })
      vim.keymap.set("n", "[F", function() ts_move.goto_previous_end("@function.outer") end,   { desc = "TS: Prev func end" })
      vim.keymap.set("n", "[C", function() ts_move.goto_previous_end("@class.outer") end,      { desc = "TS: Prev class end" })

      -- Swap keymaps
      vim.keymap.set("n", "<leader>ap", function() ts_swap.swap_next("@parameter.inner") end,     { desc = "TS: Swap next param" })
      vim.keymap.set("n", "<leader>aP", function() ts_swap.swap_previous("@parameter.inner") end, { desc = "TS: Swap prev param" })

      -- Sticky context: shows current function/class at top of screen
      require("treesitter-context").setup({
        enable    = true,
        max_lines = 3,
      })

      -- ============================================================
      -- LSP
      -- Provides: go-to-definition, hover docs, inline diagnostics,
      -- rename, code actions, and formatting.
      -- Uses vim.lsp.config / vim.lsp.enable (nvim-lspconfig v3+ API).
      -- ============================================================
      vim.diagnostic.config({
        virtual_text     = { prefix = "●" },
        signs            = true,
        underline        = true,
        update_in_insert = false,
        severity_sort    = true,
        float            = { border = "rounded", source = "always" },
      })

      -- Apply cmp capabilities to every server
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      -- Server-specific settings
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime   = { version = "LuaJIT" },
            workspace = {
              checkThirdParty = false,
              library         = vim.api.nvim_get_runtime_file("", true),
            },
            telemetry = { enable = false },
          },
        },
      })

      -- Enable servers (add more here as needed: "rust_analyzer", "gopls", etc.)
      vim.lsp.enable({ "lua_ls", "nil_ls", "bashls" })

      -- LSP keymaps — set once per buffer when any LSP client attaches
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local bufnr = ev.buf
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
          end
          -- Navigation
          map("gd",         vim.lsp.buf.definition,       "LSP: Go to Definition")
          map("gD",         vim.lsp.buf.declaration,      "LSP: Go to Declaration")
          map("gr",         vim.lsp.buf.references,       "LSP: References")
          map("gI",         vim.lsp.buf.implementation,   "LSP: Implementation")
          map("gy",         vim.lsp.buf.type_definition,  "LSP: Type Definition")
          map("K",          vim.lsp.buf.hover,            "LSP: Hover Docs")
          map("<C-k>",      vim.lsp.buf.signature_help,   "LSP: Signature Help")
          -- Code operations (under <leader>c group)
          map("<leader>cr", vim.lsp.buf.rename,           "LSP: Rename Symbol")
          map("<leader>ca", vim.lsp.buf.code_action,      "LSP: Code Action")
          map("<leader>cf", function()
            vim.lsp.buf.format({ async = true })
          end, "LSP: Format Buffer")
          map("<leader>cd", vim.diagnostic.open_float,    "LSP: Show Diagnostic")
          -- Diagnostic navigation
          map("[d",         vim.diagnostic.goto_prev,     "LSP: Prev Diagnostic")
          map("]d",         vim.diagnostic.goto_next,     "LSP: Next Diagnostic")
        end,
      })

      -- LSP progress indicator (bottom-right spinner)
      require("fidget").setup({})

      -- ============================================================
      -- COMPLETION
      -- Provides: popup completion from LSP, buffer words, paths, and
      -- snippet expansion via LuaSnip.
      -- ============================================================
      local cmp     = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      cmp.setup({
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ["<C-n>"]     = cmp.mapping.select_next_item(),
          ["<C-p>"]     = cmp.mapping.select_prev_item(),
          ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
          ["<C-f>"]     = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"]     = cmp.mapping.abort(),
          ["<CR>"]      = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        window = {
          completion    = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })

      -- ============================================================
      -- TELESCOPE  (Helix-style space pickers)
      -- <leader><space>  file picker
      -- <leader>/        live grep
      -- <leader>b        buffer picker
      -- <leader>s/S      symbol pickers
      -- etc.
      -- ============================================================
      local telescope = require("telescope")
      local builtin   = require("telescope.builtin")

      telescope.setup({
        defaults = {
          sorting_strategy = "ascending",
          layout_config    = { prompt_position = "top" },
          border           = true,
        },
        extensions = {
          fzf = {
            fuzzy                   = true,
            override_generic_sorter = true,
            override_file_sorter    = true,
            case_mode               = "smart_case",
          },
        },
      })
      telescope.load_extension("fzf")

      vim.keymap.set("n", "<leader><space>", builtin.find_files,                    { desc = "Find Files" })
      vim.keymap.set("n", "<leader>/",       builtin.live_grep,                     { desc = "Live Grep" })
      vim.keymap.set("n", "<leader>b",       builtin.buffers,                       { desc = "Buffers" })
      vim.keymap.set("n", "<leader>h",       builtin.help_tags,                     { desc = "Help Tags" })
      vim.keymap.set("n", "<leader>r",       builtin.oldfiles,                      { desc = "Recent Files" })
      vim.keymap.set("n", "<leader>d",       builtin.diagnostics,                   { desc = "Diagnostics" })
      vim.keymap.set("n", "<leader>s",       builtin.lsp_document_symbols,          { desc = "Symbols" })
      vim.keymap.set("n", "<leader>S",       builtin.lsp_dynamic_workspace_symbols, { desc = "Workspace Symbols" })
      vim.keymap.set("n", "<leader>gf",      builtin.git_files,                     { desc = "Git: Files" })
      vim.keymap.set("n", "<leader>gc",      builtin.git_commits,                   { desc = "Git: Commits" })

      -- ============================================================
      -- WHICH-KEY  (shows available keybinds after <leader>)
      -- ============================================================
      local wk = require("which-key")
      wk.setup({ delay = 300 })
      wk.add({
        { "<leader>a", group = "args (swap)" },
        { "<leader>c", group = "code" },
        { "<leader>g", group = "git" },
        { "<leader>t", group = "trouble" },
      })

      -- ============================================================
      -- GITSIGNS  (inline git decorations, blame, diff)
      -- ============================================================
      require("gitsigns").setup({
        signs = {
          add          = { text = "▎" },
          change       = { text = "▎" },
          delete       = { text = "" },
          topdelete    = { text = "" },
          changedelete = { text = "▎" },
          untracked    = { text = "▎" },
        },
        on_attach = function(bufnr)
          local gs  = package.loaded.gitsigns
          local map = function(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
          end
          map("n", "]g",           gs.next_hunk,                                   "Git: Next Hunk")
          map("n", "[g",           gs.prev_hunk,                                   "Git: Prev Hunk")
          map("n", "<leader>gs",   gs.stage_hunk,                                  "Git: Stage Hunk")
          map("n", "<leader>gR",   gs.reset_hunk,                                  "Git: Reset Hunk")
          map("n", "<leader>gS",   gs.stage_buffer,                                "Git: Stage Buffer")
          map("n", "<leader>gu",   gs.undo_stage_hunk,                             "Git: Undo Stage")
          map("n", "<leader>gX",   gs.reset_buffer,                                "Git: Reset Buffer")
          map("n", "<leader>gp",   gs.preview_hunk,                                "Git: Preview Hunk")
          map("n", "<leader>gb",   function() gs.blame_line({ full = true }) end,  "Git: Blame Line")
          map("n", "<leader>gd",   gs.diffthis,                                    "Git: Diff This")
          map("n", "<leader>gtb",  gs.toggle_current_line_blame,                   "Git: Toggle Blame")
        end,
      })

      -- ============================================================
      -- NEO-TREE  (file explorer)
      -- ============================================================
      require("neo-tree").setup({
        close_if_last_window = true,
        window = { width = 30 },
        filesystem = {
          follow_current_file    = { enabled = true },
          use_libuv_file_watcher = true,
          filtered_items = {
            visible         = false,
            hide_dotfiles   = false,
            hide_gitignored = true,
          },
        },
      })
      vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "File Explorer" })
      vim.keymap.set("n", "<leader>E", "<cmd>Neotree reveal<cr>", { desc = "Reveal in Explorer" })

      -- ============================================================
      -- LUALINE  (statusline)
      -- ============================================================
      require("lualine").setup({
        options = {
          theme                = "auto",
          component_separators = { left = "", right = "" },
          section_separators   = { left = "", right = "" },
          globalstatus         = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })

      -- ============================================================
      -- BUFFERLINE  (buffer tabs)
      -- ============================================================
      require("bufferline").setup({
        options = {
          mode                    = "buffers",
          diagnostics             = "nvim_lsp",
          show_buffer_close_icons = false,
          show_close_icon         = false,
          separator_style         = "thin",
        },
      })
      vim.keymap.set("n", "]b", "<cmd>BufferLineCycleNext<cr>", { desc = "Next Buffer" })
      vim.keymap.set("n", "[b", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev Buffer" })
      vim.keymap.set("n", "]B", "<cmd>BufferLineGoToBuffer -1<cr>", { desc = "Last Buffer" })
      vim.keymap.set("n", "[B", "<cmd>BufferLineGoToBuffer 1<cr>",  { desc = "First Buffer" })

      -- ============================================================
      -- NVIM-SURROUND  (ys/cs/ds surround operations)
      -- ============================================================
      require("nvim-surround").setup({})

      -- ============================================================
      -- AUTOPAIRS  (auto-close brackets and quotes)
      -- ============================================================
      require("nvim-autopairs").setup({ check_ts = true })
      -- Integrate with cmp so <CR> doesn't double-insert closing char
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())

      -- ============================================================
      -- INDENT-BLANKLINE  (indent guides + scope highlight)
      -- ============================================================
      require("ibl").setup({
        indent = { char = "│" },
        scope  = { enabled = true },
      })

      -- ============================================================
      -- TROUBLE  (diagnostics / references panel)
      -- ============================================================
      require("trouble").setup({})
      vim.keymap.set("n", "<leader>tt", "<cmd>Trouble diagnostics toggle<cr>",              { desc = "Trouble: All Diagnostics" })
      vim.keymap.set("n", "<leader>tT", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Trouble: Buffer Diagnostics" })
      vim.keymap.set("n", "<leader>ts", "<cmd>Trouble symbols toggle<cr>",                  { desc = "Trouble: Symbols" })
      vim.keymap.set("n", "<leader>tl", "<cmd>Trouble lsp toggle<cr>",                      { desc = "Trouble: LSP" })

      -- ============================================================
      -- COMMENT.NVIM  (gcc = line, gc = visual)
      -- ============================================================
      require("Comment").setup({})

      -- ============================================================
      -- FLASH.NVIM  (jump to any visible position)
      -- gs  = jump by label (like Helix's gw / s)
      -- gS  = jump by treesitter node
      -- Does NOT override s/S — they remain substitute/substitute-line
      -- ============================================================
      require("flash").setup({})
      vim.keymap.set({ "n", "x", "o" }, "gs", function() require("flash").jump() end,       { desc = "Flash: Jump" })
      vim.keymap.set({ "n", "x", "o" }, "gS", function() require("flash").treesitter() end, { desc = "Flash: Treesitter Node" })

      -- ============================================================
      -- VIM-VISUAL-MULTI  (multi-cursor — Ctrl-N to select next match)
      -- ============================================================
      -- Uses its own default bindings; no extra setup needed.

      -- ============================================================
      -- GENERAL KEYMAPS
      -- ============================================================
      -- Clear search highlight
      vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear Highlight" })

      -- Move selected lines up/down in visual mode
      vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move Lines Down" })
      vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv",  { desc = "Move Lines Up" })

      -- Keep cursor centred while scrolling / searching
      vim.keymap.set("n", "<C-d>", "<C-d>zz",  { desc = "Scroll Down" })
      vim.keymap.set("n", "<C-u>", "<C-u>zz",  { desc = "Scroll Up" })
      vim.keymap.set("n", "n",     "nzzzv",    { desc = "Next Match" })
      vim.keymap.set("n", "N",     "Nzzzv",    { desc = "Prev Match" })
    '';
  };
}
