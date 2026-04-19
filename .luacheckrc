ignore = {
  "631",    -- max_line_length
}
read_globals = {
  "vim",
  "describe",
  "it",
  "assert"
}
exclude_files = {
  "**/fun/**"
}
files["scripts/minimal_init.lua"] = {
  -- minimal_init.lua must write vim.g and vim.opt to configure Neovim for tests
  globals = { "vim" },
}
