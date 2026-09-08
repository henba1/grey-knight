-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Avante.nvim — Cursor-style AI agent sidebar               ║
-- ║  → Qwen 3.8 27B @ 192.168.2.173:8000 (llama.cpp)          ║
-- ╚══════════════════════════════════════════════════════════════╝
return {
  -- render-markdown (standalone, also used by Avante)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = { file_types = { "markdown", "Avante" } },
  },

  -- Avante
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    build = "make",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      provider = "qwen-local",
      mode = "agentic",
      hints = { enabled = true },
      windows = {
        position = "right",
        width = 40,
      },
      providers = {
        ["qwen-local"] = {
          __inherited_from = "openai",
          endpoint = "http://192.168.2.173:8000/v1",
          model = "local-model",
          api_key_name = "",
          timeout = 120000,
          extra_request_body = {
            temperature = 0.7,
            max_tokens = 8192,
          },
        },
      },
    },
    keys = {
      { "<leader>at", "<cmd>AvanteToggle<cr>",  desc = "AI: Toggle sidebar" },
      { "<leader>ac", "<cmd>AvanteChat<cr>",     desc = "AI: New chat" },
      { "<leader>aa", "<cmd>AvanteAsk<cr>",      mode = { "n", "v" }, desc = "AI: Ask" },
      { "<leader>ae", "<cmd>AvanteEdit<cr>",     mode = "v",          desc = "AI: Edit selection" },
    },
  },
}
