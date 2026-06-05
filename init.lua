-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Leader key (must be set before lazy)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.filetype.add({
  extension = { mdx = "mdx" },
  pattern = { [".*%.yml%.hbs"] = "yaml" },
})
vim.treesitter.language.register("markdown", "mdx")

-- Plugin specs
require("lazy").setup({
  -- Colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      local current
      local function apply_theme()
        local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
        local is_dark = false
        if handle then
          is_dark = handle:read("*a"):match("Dark") ~= nil
          handle:close()
        end
        if is_dark == current then return end
        current = is_dark
        vim.o.background = is_dark and "dark" or "light"
        require("catppuccin").setup({ flavour = is_dark and "frappe" or "latte" })
        vim.cmd.colorscheme("catppuccin")
      end
      apply_theme()
      local timer = vim.uv.new_timer()
      timer:start(500, 500, vim.schedule_wrap(apply_theme))
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "lua", "typescript", "javascript", "tsx", "go", "python",
          "json", "yaml", "markdown", "markdown_inline", "bash", "html", "css", "vimdoc",
        },
        highlight = { enable = true },
      })
    end,
  },

  -- mini.nvim
  {
    "echasnovski/mini.nvim",
    config = function()
      require("mini.basics").setup()
      require("mini.files").setup({
        content = { filter = function() return true end },
      })
      require("mini.pick").setup()
      require("mini.statusline").setup({ use_icons = false })
      require("mini.surround").setup()
      require("mini.pairs").setup()
      require("mini.comment").setup()
      require("mini.ai").setup()
      require("mini.git").setup()
      require("mini.clue").setup({
        triggers = {
          { mode = "n", keys = "<leader>" },
          { mode = "x", keys = "<leader>" },
          { mode = "n", keys = "g" },
          { mode = "n", keys = "z" },
        },
        clues = {
          require("mini.clue").gen_clues.g(),
          require("mini.clue").gen_clues.z(),
        },
        window = { delay = 300 },
      })
    end,
  },

  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "mdx" },
    opts = {
      heading = { enabled = true },
      code = { enabled = true },
      bullet = { enabled = true },
      checkbox = { enabled = true },
      table = { enabled = true },
    },
  },

  -- Zen mode
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    opts = {
      window = { width = 90 },
      plugins = { options = { laststatus = 0 } },
    },
  },

  -- Completion
  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = { preset = "super-tab" },
      completion = {
        documentation = { auto_show = true },
      },
      sources = {
        default = { "lsp", "path", "buffer" },
      },
    },
  },
}, {
  ui = {
    icons = {
      cmd = "cmd",
      config = "cfg",
      event = "event",
      ft = "ft",
      init = "init",
      keys = "keys",
      plugin = "plugin",
      runtime = "rt",
      require = "req",
      source = "src",
      start = "start",
      task = "task",
      lazy = "lazy",
    },
  },
})

-- Editor options (beyond what mini.basics sets)
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.scrolloff = 8
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.undofile = true

-- Filetype overrides
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = false
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "mdx" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
  end,
})

-- Native LSP (Neovim 0.11+)
vim.lsp.config("*", {
  root_markers = { ".git" },
})
vim.lsp.enable({ "ts_ls", "gopls", "pyright", "marksman" })

-- LspAttach autocmd
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client then return end

    -- LSP keybindings (buffer-local)
    local opts = function(desc) return { buffer = args.buf, desc = desc } end
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts("Go to definition"))
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts("Go to declaration"))
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts("Find references"))
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts("Go to implementation"))
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts("Hover documentation"))
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts("Rename symbol"))
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts("Code action"))

    -- Format on save
    if client:supports_method("textDocument/formatting") then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = args.buf,
        callback = function()
          vim.lsp.buf.format({ bufnr = args.buf, id = client.id })
        end,
      })
    end
  end,
})

-- Keymaps
-- mini.pick (wrapped in functions to defer MiniPick resolution)
vim.keymap.set("n", "<leader>ff", function()
  MiniPick.builtin.cli({
    command = { "rg", "--files", "--hidden", "--no-ignore", "--glob=!.git", "--color=never" },
  }, { source = { name = "Files (rg)" } })
end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function()
  local cwd = vim.fn.getcwd()
  local set_items_opts = { do_match = false, querytick = 0 }
  local spawn_opts = { cwd = cwd }
  local sys = { kill = function() end }
  local tick = 0

  local match = function(_, _, query)
    sys:kill()
    tick = tick + 1
    if #query == 0 then
      sys = { kill = function() end }
      return MiniPick.set_picker_items({}, set_items_opts)
    end
    set_items_opts.querytick = tick
    local cmd = {
      "rg", "--hidden", "--no-ignore", "--glob=!.git",
      "--column", "--line-number", "--no-heading",
      "--field-match-separator", "\\x00", "--color=never",
    }
    if vim.o.ignorecase then
      table.insert(cmd, vim.o.smartcase and "--smart-case" or "--ignore-case")
    else
      table.insert(cmd, "--case-sensitive")
    end
    table.insert(cmd, "--")
    table.insert(cmd, table.concat(query))
    sys = MiniPick.set_picker_items_from_cli(cmd, {
      set_items_opts = set_items_opts,
      spawn_opts = spawn_opts,
    })
  end

  MiniPick.start({
    source = { items = {}, name = "Grep live (rg)", match = match },
  })
end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", function() MiniPick.builtin.buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fo", function() require("mini.extra").pickers.oldfiles() end, { desc = "Recent files" })

-- mini.files
vim.keymap.set("n", "<leader>e", function()
  if not MiniFiles.close() then MiniFiles.open() end
end, { desc = "Toggle file explorer" })

-- Open mini.files entry in a split
local mini_files_open_in_split = function(direction)
  local entry = MiniFiles.get_fs_entry()
  if not entry or entry.fs_type ~= "file" then return end
  MiniFiles.close()
  vim.cmd(direction .. " " .. vim.fn.fnameescape(entry.path))
end

vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesBufferCreate",
  callback = function(args)
    local buf = args.data.buf_id
    vim.keymap.set("n", "<C-v>", function() mini_files_open_in_split("vsplit") end, { buffer = buf, desc = "Open in vertical split" })
    vim.keymap.set("n", "<C-x>", function() mini_files_open_in_split("split") end, { buffer = buf, desc = "Open in horizontal split" })
  end,
})

-- Split navigation
vim.keymap.set("n", "<leader>h", "<C-w>h", { desc = "Move to left split" })
vim.keymap.set("n", "<leader>j", "<C-w>j", { desc = "Move to below split" })
vim.keymap.set("n", "<leader>k", "<C-w>k", { desc = "Move to above split" })
vim.keymap.set("n", "<leader>l", "<C-w>l", { desc = "Move to right split" })

-- Convenience
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })

-- Diagnostics
vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, { desc = "Diagnostic float" })

-- Zen mode
vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", { desc = "Zen mode" })
