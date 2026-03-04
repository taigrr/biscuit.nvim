# AGENTS.md

Agent guidelines for working in `biscuit.nvim`.

## Project Overview

Neovim plugin (Lua) for batch-applying LSP quickfix actions by diagnostic code across projects. Loads files into LSP to get project-wide diagnostics without manually opening each file.

## Structure

```
lua/biscuit/
├── init.lua        # Entry point, setup(), config
├── actions.lua     # Diagnostic code matching and quickfix application
├── commands.lua    # User command definitions (:LoadLSP, :ApplyFixes, etc.)
├── formatters.lua  # LSP formatting for loaded buffers
├── loader.lua      # File discovery (fd/glob), buffer loading, LSP utils
└── health.lua      # :checkhealth biscuit

plugin/
└── biscuit.lua     # Guard for double-load

doc/
└── biscuit.txt     # Vimdoc

docs/
├── biscuit-dark.svg
└── biscuit-light.svg
```

## Commands

Run tests locally (requires plenary.nvim):

```bash
make test
```

Or manually test by loading in Neovim:

```vim
" From the repo directory:
:set runtimepath+=.
:lua require('biscuit').setup({ codes = {'any', 'slicescontains'} })
```

## Key Implementation Details

### Diagnostic Code Matching

- Filters diagnostics by `diag.code` field (exact string match via `tostring()`)
- Only applies quickfix actions (kind == "quickfix" or starts with "quickfix.")
- Applies first quickfix action when at least one exists

### File Discovery

- Uses `fd` if available (async via libuv), falls back to `vim.fn.globpath`

## Style Guidelines

- **Naming**: `snake_case` for functions/variables, `PascalCase` for class annotations
- **Strings**: Single quotes for Lua strings
- **Indentation**: 2 spaces

## Dependencies

- Neovim 0.10+ (required)
- `fd` (recommended for faster file discovery)
- LSP servers configured for target filetypes
