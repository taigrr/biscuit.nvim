<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/taigrr/biscuit.nvim/raw/master/docs/biscuit-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/taigrr/biscuit.nvim/raw/master/docs/biscuit-light.svg">
  <img alt="biscuit.nvim" src="https://github.com/taigrr/biscuit.nvim/raw/master/docs/biscuit-dark.svg" width="400">
</picture>

<p>
  <a href="https://github.com/taigrr/biscuit.nvim/releases/latest">
    <img alt="Latest release" src="https://img.shields.io/github/v/release/taigrr/biscuit.nvim?style=for-the-badge&logo=starship&color=D4A574&logoColor=D9E0EE&labelColor=302D41&sort=semver&include_prerelease">
  </a>
  <a href="https://github.com/taigrr/biscuit.nvim/pulse">
    <img alt="Last commit" src="https://img.shields.io/github/last-commit/taigrr/biscuit.nvim?style=for-the-badge&logo=starship&color=8bd5ca&labelColor=302D41&logoColor=D9E0EE">
  </a>
  <a href="https://github.com/taigrr/biscuit.nvim/blob/master/LICENSE">
    <img alt="License" src="https://img.shields.io/github/license/taigrr/biscuit.nvim?style=for-the-badge&logo=starship&color=ee999f&labelColor=302D41&logoColor=D9E0EE">
  </a>
  <a href="https://github.com/taigrr/biscuit.nvim/stargazers">
    <img alt="Stars" src="https://img.shields.io/github/stars/taigrr/biscuit.nvim?style=for-the-badge&logo=starship&color=c69ff5&labelColor=302D41&logoColor=D9E0EE">
  </a>
</p>

**Batch quickfix actions and LSP formatting across your entire project.**

Biscuit loads files into LSP for project-wide diagnostics and lets you batch-apply quickfix actions for specific diagnostic codes (like gopls's `any`, `slicescontains`, etc.) across hundreds of files at once.

## The Problem

You have 200 Go files with `interface{}` that should be `any`. Opening each file, waiting for LSP, and applying the quickfix manually would take hours.

## The Solution

```vim
:LoadLSP                  " Load all Go files into LSP
:ApplyFixes any           " Fix all 200 files in seconds
```

## Features

- **Load files into LSP** — Get diagnostics for your entire project
- **Batch quickfix by diagnostic code** — Specify codes like `any`, `slicescontains`, `printf`
- **Safe by default** — Only applies quickfix-kind actions, picking the first match
- **Batch LSP formatting** — Run `textDocument/formatting` on all loaded buffers
- **Dry run mode** — Preview changes before applying

## Requirements

- Neovim >= **0.10.0**
- `fd` (recommended) or `find` for file discovery
- LSP server(s) configured for your filetypes

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "taigrr/biscuit.nvim",
  cmd = { "LoadLSP", "ApplyFixes", "ListDiagnosticCodes", "FormatBuffers" },
  opts = {
    codes = {
      "any",              -- interface{} -> any
      "slicescontains",   -- Use slices.Contains
      "printf",           -- Printf format issues
    },
  },
}
```

## Quick Start

```vim
" 1. Open a Go file to set filetype
:e main.go

" 2. Load all Go files into LSP
:LoadLSP

" 3. See what diagnostic codes are available
:ListDiagnosticCodes

" 4. Apply fixes (dry run first)
:ApplyFixes! any
:ApplyFixes any

" 5. Or apply all configured codes
:ApplyFixes

" 6. Format all loaded buffers
:FormatBuffers

" 7. Clean up
:UnloadHidden
```

## Commands

| Command | Description |
|---------|-------------|
| `:LoadLSP [dir] [exts...]` | Load files into LSP (uses current filetype if no args) |
| `:UnloadHidden` | Unload hidden buffers to free resources |
| `:ApplyFixes[!] [codes...]` | Apply quickfixes for diagnostic codes. `!` for dry run |
| `:ListDiagnosticCodes` | List diagnostic codes from loaded buffers |
| `:ListConfiguredCodes` | List configured codes |
| `:FormatBuffers[!]` | Format all loaded buffers using LSP. `!` for dry run |

## Configuration

```lua
require("biscuit").setup({
  -- Diagnostic codes to auto-fix (exact match)
  -- These are the "code" field from LSP diagnostics
  codes = {
    "any",              -- gopls: interface{} -> any
    "slicescontains",   -- gopls: Use slices.Contains
    "printf",           -- gopls: Printf format specifier issues
    "unusedwrite",      -- gopls: Unused write to variable
  },
  
  -- Performance options
  batch_size = 10,       -- Files per batch when loading
  batch_delay = 50,      -- Ms between batches
  max_files = 0,         -- Limit files (0 = unlimited)
  auto_save = true,      -- Save after applying actions/formatting
  
  -- Directories to skip
  exclude_dirs = {
    "node_modules", ".git", "dist", "build",
    "__pycache__", ".venv", "vendor", ".next", "coverage",
  },
})
```

## Common Diagnostic Codes

### gopls (Go)

| Code | Description |
|------|-------------|
| `any` | Use `any` instead of `interface{}` |
| `slicescontains` | Use `slices.Contains` instead of loop |
| `printf` | Printf format specifier issues |
| `unusedwrite` | Unused write to variable |
| `fillstruct` | Fill struct with zero values |
| `undeclaredname` | Undeclared name |

### typescript-language-server

| Code | Description |
|------|-------------|
| `6133` | Unused variable |
| `6196` | Unused import |

Run `:ListDiagnosticCodes` after `:LoadLSP` to see what codes your LSP provides.

## How It Works

1. **Load files** — `:LoadLSP` loads matching files into buffers for LSP analysis
2. **Filter diagnostics** — Finds diagnostics matching your configured codes
3. **Request code actions** — For each matching diagnostic, requests quickfix actions
4. **Apply if unique** — Only applies when exactly ONE quickfix action exists
5. **Auto-save** — Optionally saves modified files

## Health Check

```vim
:checkhealth biscuit
```

## Tips

- **Discover codes**: Run `:ListDiagnosticCodes` to see what your LSP provides
- **Start with dry run**: Use `!` to preview changes first
- **Clean up**: Run `:UnloadHidden` after batch operations to free memory

## License

[0BSD](LICENSE) (c) [Tai Groot](https://github.com/taigrr)
