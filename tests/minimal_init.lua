vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend(os.getenv("PLENARY_DIR") or vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
vim.cmd("runtime plugin/plenary.vim")
require("prompt").setup({ db_path = "/tmp/test_prompts.db" })
