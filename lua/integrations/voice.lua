-- ╔══════════════════════════════════════════════════════════════╗
-- ║  Speech to text, on the machine Neovim runs on:              ║
-- ║    <leader>av - speak a prompt to the agent                  ║
-- ║    <leader>aV - dictate at the cursor (a terminal: typed in) ║
-- ║  Press to start, again to stop; :VoiceCancel drops it.       ║
-- ║  Recording: pw-record, parecord, arecord, ffmpeg or sox on   ║
-- ║  Linux; Windows' own (winmm, through PowerShell).            ║
-- ║  Transcribing: whisper.cpp here (:VoiceInstall), or an       ║
-- ║  OpenAI-compatible server when $GREYKNIGHT_STT_URL says so - ║
-- ║  set by hand, never in git.                                  ║
-- ╚══════════════════════════════════════════════════════════════╝
local M = {}

local WIN = vim.fn.has("win32") == 1

local function notify(msg, level, opts)
  return vim.notify(msg, level or vim.log.levels.INFO, vim.tbl_extend("force", { title = "Voice", id = "greyknight_voice" }, opts or {}))
end

-- ── whisper.cpp: what :VoiceInstall puts here, pinned and checked ─

--- Where :VoiceInstall puts whisper.cpp, its models and the sample
M.DIR = vim.fn.stdpath("data") .. "/whisper"
--- whisper.cpp's build (its nightly release - the versioned ones carry no binaries) and the packages of it
M.RELEASE = "b5454"
M.PACKAGES = {
  ["windows-x64"] = { file = "whisper-bin-x64.zip", sha256 = "6ba69e3482d7826214f90a6a9c84ca07782aec1e1d0c6a7c30c994fd5d816ccb" },
  ["linux-x64"] = { file = "whisper-bin-ubuntu-x64.tar.gz", sha256 = "a72becf15d7917f990f6313867a52638b82b7f9ef237fb0c980dac56a135781c" },
  ["linux-arm64"] = { file = "whisper-bin-ubuntu-arm64.tar.gz", sha256 = "6b95ebfc60447df48e70ef00a73bdc3f41679ed2d01ef465827206a2ff325149" },
}
--- The models (Hugging Face, ggerganov/whisper.cpp): small is the default - German and English well, quick on a CPU
M.MODELS = {
  small = { file = "ggml-small-q5_1.bin", mb = 190, sha256 = "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb" },
  base = { file = "ggml-base-q5_1.bin", mb = 60, sha256 = "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898" },
  turbo = { file = "ggml-large-v3-turbo-q5_0.bin", mb = 574, sha256 = "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2" },
}
--- whisper.cpp's sample (JFK): the installation's check, and the tests'
M.SAMPLE = { url = "https://github.com/ggml-org/whisper.cpp/raw/v1.9.5/samples/jfk.wav", file = "jfk.wav",
  sha256 = "59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e" }

local EXE = WIN and "whisper-cli.exe" or "whisper-cli"

--- whisper.cpp's whisper-cli: $GREYKNIGHT_WHISPER, the one :VoiceInstall put here, else one on the PATH
function M.whisper()
  local own = vim.env.GREYKNIGHT_WHISPER
  if own and own ~= "" then return vim.fn.executable(own) == 1 and own or nil end
  local found = vim.fs.find(EXE, { path = M.DIR .. "/" .. M.RELEASE, type = "file", limit = 1 })[1]
  if found and vim.fn.executable(found) == 1 then return found end
  for _, name in ipairs({ "whisper-cli", "whisper-cpp" }) do
    if vim.fn.executable(name) == 1 then return vim.fn.exepath(name) end
  end
end

--- The model: $GREYKNIGHT_WHISPER_MODEL, else one :VoiceInstall put here (small, turbo, base - the first there)
function M.model()
  local own = vim.env.GREYKNIGHT_WHISPER_MODEL
  if own and own ~= "" then return vim.fn.filereadable(own) == 1 and own or nil end
  for _, name in ipairs({ "small", "turbo", "base" }) do
    local path = M.DIR .. "/models/" .. M.MODELS[name].file
    if vim.fn.filereadable(path) == 1 then return path end
  end
end

--- An OpenAI-compatible server to transcribe with instead ($GREYKNIGHT_STT_URL, e.g. http://host:8000/v1) - set by hand
function M.url()
  local url = vim.env.GREYKNIGHT_STT_URL
  return url and url ~= "" and (url:gsub("/+$", "")) or nil
end

-- ── Recording ──────────────────────────────────────────────────

-- Windows: winmm's MCI through PowerShell - in every Windows, nothing to install. RECORDING once it records; a line
-- on stdin stops it, SAVED once the file is written. ASCII only (PowerShell 5.1)
local RECORD_PS = [[
$ErrorActionPreference = 'Stop'
$path = '%s'
Add-Type -Namespace GreyKnight -Name Mci -MemberDefinition '[DllImport("winmm.dll", CharSet = CharSet.Unicode)] public static extern int mciSendStringW(string command, System.Text.StringBuilder ret, int size, System.IntPtr hwnd);'
function Mci([string]$c) { $b = New-Object System.Text.StringBuilder 512; $r = [GreyKnight.Mci]::mciSendStringW($c, $b, 512, [IntPtr]::Zero); if ($r -ne 0) { throw ('MCI error ' + $r + ': ' + $c) } }
Mci 'open new type waveaudio alias gkvoice'
Mci 'set gkvoice time format ms bitspersample 16 channels 1 samplespersec 16000 bytespersec 32000 alignment 2'
Mci 'record gkvoice'
[Console]::Out.WriteLine('RECORDING'); [Console]::Out.Flush()
[void][Console]::In.ReadLine()
Mci 'stop gkvoice'
Mci ('save gkvoice "' + $path + '"')
Mci 'close gkvoice'
[Console]::Out.WriteLine('SAVED'); [Console]::Out.Flush()
]]

--- The recorder for `file` (16 kHz mono WAV): its command and how it stops - "signal" (Ctrl+C) or "stdin" (a line);
--- nil when there is none
function M.recorder(file)
  if WIN then
    local script = RECORD_PS:format(file:gsub("'", "''"))
    return { "powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script }, "stdin"
  end
  for _, r in ipairs({
    { "pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", file },
    { "parecord", "--rate=16000", "--channels=1", "--format=s16le", "--file-format=wav", file },
    { "arecord", "-q", "-f", "S16_LE", "-r", "16000", "-c", "1", file },
    { "ffmpeg", "-loglevel", "error", "-f", "pulse", "-i", "default", "-ac", "1", "-ar", "16000", "-y", file },
    { "rec", "-q", "-c", "1", "-r", "16000", file },
  }) do
    if vim.fn.executable(r[1]) == 1 then return r, "signal" end
  end
end

--- Over SSH the microphone is on the computer the user sits at, not here (a desktop session of this machine aside)
function M.remote()
  return not WIN and (vim.env.SSH_CONNECTION or "") ~= "" and (vim.env.DISPLAY or "") == "" and (vim.env.WAYLAND_DISPLAY or "") == ""
end

-- ── Transcribing ───────────────────────────────────────────────

-- whisper's marks for what was no speech: [BLANK_AUDIO], (music), [ Silence ]
local function clean(text)
  text = text:gsub("%b[]", " "):gsub("%b()", " "):gsub("%s+", " ")
  return vim.trim(text)
end

--- The text spoken in `file`: done(text) or done(nil, why)
function M.transcribe(file, done)
  local lang = vim.env.GREYKNIGHT_STT_LANG
  local url = M.url()
  if url then
    local cmd = { "curl", "-sS", "--max-time", "120", "-X", "POST", url .. "/audio/transcriptions", "-F", "file=@" .. file,
      "-F", "model=" .. ((vim.env.GREYKNIGHT_STT_MODEL or "") ~= "" and vim.env.GREYKNIGHT_STT_MODEL or "whisper-1") }
    if lang and lang ~= "" then vim.list_extend(cmd, { "-F", "language=" .. lang }) end
    local headers
    if (vim.env.GREYKNIGHT_STT_KEY or "") ~= "" then -- in a file of this Neovim's, not on a command line others can read
      headers = vim.fn.tempname() .. "-headers"
      vim.fn.writefile({ "Authorization: Bearer " .. vim.env.GREYKNIGHT_STT_KEY }, headers)
      vim.list_extend(cmd, { "-H", "@" .. headers })
    end
    return vim.system(cmd, { text = true }, vim.schedule_wrap(function(res)
      if headers then os.remove(headers) end
      local ok, data = pcall(vim.json.decode, res.stdout or "")
      if res.code ~= 0 or not ok or type(data) ~= "table" or type(data.text) ~= "string" then
        return done(nil, ("%s did not transcribe it: %s"):format(url, vim.trim((res.stderr or "") .. " " .. (res.stdout or "")):sub(1, 200)))
      end
      done(clean(data.text))
    end))
  end
  local bin, model = M.whisper(), M.model()
  if not bin or not model then
    return done(nil, "no whisper.cpp here - :VoiceInstall downloads it (or $GREYKNIGHT_STT_URL names a server)")
  end
  local threads = tostring(math.max(1, math.min(8, #vim.uv.cpu_info())))
  local cmd = { bin, "-m", model, "-f", file, "-l", (lang and lang ~= "") and lang or "auto", "-nt", "-np", "-sns", "-t", threads }
  if WIN and bin:lower():match("%.[cb][ma][dt]$") then table.insert(cmd, 1, "/c"); table.insert(cmd, 1, "cmd") end -- a wrapper script
  vim.system(cmd, { text = true }, vim.schedule_wrap(function(res)
      if res.code ~= 0 then return done(nil, "whisper.cpp: " .. vim.trim(res.stderr or ""):sub(1, 200)) end
      done(clean(res.stdout or ""))
    end))
end

-- ── Where the words go ─────────────────────────────────────────

--- To the agent: shown first - right what whisper heard wrong, Enter sends it
local function to_agent(text)
  local agent = require("integrations.agent")
  vim.ui.input({ prompt = ("To %s: "):format(agent.backend().short), default = text }, function(prompt)
    if prompt and vim.trim(prompt) ~= "" then agent.send(prompt) end
  end)
end

--- At the cursor of the window it started in; a terminal there gets the words typed in
local function at_cursor(text, win)
  if not (win and vim.api.nvim_win_is_valid(win)) then return notify("Dictated (the window is gone): " .. text) end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype == "terminal" then
    local job = vim.b[buf].terminal_job_id
    if job then return vim.fn.chansend(job, text) end
  end
  if not vim.bo[buf].modifiable then return notify("Dictated (the buffer cannot be changed): " .. text) end
  vim.api.nvim_win_call(win, function() vim.api.nvim_put({ text }, "c", true, true) end)
end

-- ── Start, stop ────────────────────────────────────────────────

--- The recording going on: { job, file, target, win, stop = "signal" | "stdin", cancelled }
M.current = nil
--- The longest a recording runs before it stops by itself (ms)
M.MAX = 120000

local function finish(rec)
  if rec.timer then rec.timer:stop() end
  M.current = nil
  if rec.cancelled then
    os.remove(rec.file)
    return notify("Dropped")
  end
  local stat = vim.uv.fs_stat(rec.file)
  if not stat or stat.size <= 44 then -- a WAV header and nothing after it
    os.remove(rec.file)
    return notify("Nothing was recorded - is a microphone there?", vim.log.levels.WARN)
  end
  notify("Transcribing ...", vim.log.levels.INFO, { timeout = false })
  M.transcribe(rec.file, function(text, err)
    os.remove(rec.file)
    if not text then return notify(err, vim.log.levels.WARN) end
    if text == "" then return notify("No words heard", vim.log.levels.WARN) end
    notify(text, vim.log.levels.INFO, { timeout = 3000 })
    if rec.target == "agent" then to_agent(text) else at_cursor(text, rec.win) end
  end)
end

--- Start recording for `target` ("agent" | "cursor"); while one runs: stop it
function M.toggle(target)
  if M.current then return M.stop() end
  if M.remote() then
    return notify("Over SSH the microphone is on your computer: Windows' voice typing (Win+H) types into the terminal there",
      vim.log.levels.WARN)
  end
  if not M.url() and not (M.whisper() and M.model()) then
    return notify("No whisper.cpp here - :VoiceInstall downloads it (or $GREYKNIGHT_STT_URL names a server)", vim.log.levels.WARN)
  end
  local file = vim.fn.tempname() .. "-voice.wav"
  local cmd, stop = M.recorder(file)
  if not cmd then
    return notify("No recorder here (pw-record, parecord, arecord, ffmpeg or sox)", vim.log.levels.WARN)
  end
  local rec = { file = file, target = target, win = vim.api.nvim_get_current_win(), stop = stop }
  rec.job = vim.fn.jobstart(cmd, {
    stdin = stop == "stdin" and "pipe" or "null",
    on_exit = function() vim.schedule(function() finish(rec) end) end,
  })
  if rec.job <= 0 then return notify("The recorder did not start: " .. cmd[1], vim.log.levels.WARN) end
  M.current = rec
  rec.timer = vim.defer_fn(function() if M.current == rec then M.stop() end end, M.MAX)
  local key = target == "agent" and "<leader>av" or "<leader>aV"
  notify(("Listening ... %s again stops (:VoiceCancel drops it)"):format(key), vim.log.levels.INFO, { timeout = false })
end

--- Stop the recording: it is transcribed
function M.stop()
  local rec = M.current
  if not rec then return end
  if rec.stop == "stdin" then
    pcall(vim.fn.chansend, rec.job, "stop\n")
  else
    pcall(vim.uv.kill, vim.fn.jobpid(rec.job), "sigint") -- the recorder ends its file properly
  end
end

--- Drop the recording
function M.cancel()
  if not M.current then return end
  M.current.cancelled = true
  M.stop()
end

-- ── :VoiceInstall ──────────────────────────────────────────────

--- Between two tries of a download (ms)
M.RETRY_MS = 3000

-- A file's sha256 (lowercase hex), or nil
local function sha256(file)
  local res = WIN and vim.system({ "powershell", "-NoProfile", "-Command",
      ("(Get-FileHash -Algorithm SHA256 -LiteralPath '%s').Hash"):format(file:gsub("'", "''")) }, { text = true }):wait()
    or vim.system({ "sha256sum", file }, { text = true }):wait()
  if res.code ~= 0 then return nil end
  for hex in (res.stdout or ""):gmatch("%x+") do
    if #hex == 64 then return hex:lower() end
  end
end

-- curl `url` to `dest`, checked against `sum`: done(true) or done(false, why). Three tries: GitHub refused one now and
-- then from a company's address (403, the work laptop - the next try worked, 2026-10-23)
function M.fetch(url, dest, sum, done, tries)
  tries = tries or 3
  vim.fn.mkdir(vim.fs.dirname(dest), "p")
  local part = dest .. ".part"
  vim.system({ "curl", "-fsSL", "--retry", "2", "-o", part, url }, {}, vim.schedule_wrap(function(res)
    if res.code ~= 0 then
      os.remove(part)
      if tries > 1 then return vim.defer_fn(function() M.fetch(url, dest, sum, done, tries - 1) end, M.RETRY_MS) end
      return done(false, ("download failed (curl %d): %s"):format(res.code, url))
    end
    local got = sha256(part)
    if (got or ""):lower() ~= sum then
      os.remove(part)
      return done(false, ("%s is not the file it should be (sha256 %s)"):format(vim.fs.basename(dest), tostring(got)))
    end
    os.remove(dest)
    os.rename(part, dest)
    done(true)
  end))
end

--- :VoiceInstall [small|base|turbo] - whisper.cpp (build M.RELEASE) and a model into stdpath("data")/whisper,
--- checked by sha256; then the sample transcribed once
function M.install(name)
  name = (name and name ~= "") and name or "small"
  local model = M.MODELS[name]
  if not model then return notify("Models: small (default), base, turbo", vim.log.levels.WARN) end
  local arch = (vim.uv.os_uname().machine or ""):lower()
  local platform = WIN and "windows-x64" or ((arch:find("aarch64") or arch:find("arm64")) and "linux-arm64" or "linux-x64")
  local pkg = M.PACKAGES[platform]
  local dir = M.DIR .. "/" .. M.RELEASE
  local function fail(why) notify("VoiceInstall: " .. why, vim.log.levels.ERROR) end
  local steps = {}
  if not vim.fs.find(EXE, { path = dir, type = "file", limit = 1 })[1] then
    steps[#steps + 1] = function(next)
      notify(("Downloading whisper.cpp (%s, %s) ..."):format(M.RELEASE, pkg.file), vim.log.levels.INFO, { timeout = false })
      local archive = M.DIR .. "/" .. pkg.file
      M.fetch(("https://github.com/ggml-org/whisper.cpp/releases/download/%s/%s"):format(M.RELEASE, pkg.file), archive, pkg.sha256, function(ok, why)
        if not ok then return fail(why) end
        vim.fn.mkdir(dir, "p")
        vim.system({ "tar", "-xf", archive, "-C", dir }, {}, vim.schedule_wrap(function(res)
          os.remove(archive)
          if res.code ~= 0 then return fail("could not unpack " .. pkg.file) end
          next()
        end))
      end)
    end
  end
  local model_path = M.DIR .. "/models/" .. model.file
  if vim.fn.filereadable(model_path) == 0 then
    steps[#steps + 1] = function(next)
      notify(("Downloading the model %s (%d MB) ..."):format(model.file, model.mb), vim.log.levels.INFO, { timeout = false })
      M.fetch("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" .. model.file, model_path, model.sha256, function(ok, why)
        if not ok then return fail(why) end
        next()
      end)
    end
  end
  local sample = M.DIR .. "/samples/" .. M.SAMPLE.file
  if vim.fn.filereadable(sample) == 0 then
    steps[#steps + 1] = function(next)
      M.fetch(M.SAMPLE.url, sample, M.SAMPLE.sha256, function(ok, why)
        if not ok then return fail(why) end
        next()
      end)
    end
  end
  steps[#steps + 1] = function()
    if not M.whisper() then return fail("whisper-cli is not in " .. dir) end
    notify("Installed - transcribing whisper.cpp's sample to check it ...", vim.log.levels.INFO, { timeout = false })
    local saved = vim.env.GREYKNIGHT_STT_URL
    vim.env.GREYKNIGHT_STT_URL = nil -- the check is of what was installed here
    M.transcribe(sample, function(text, err)
      vim.env.GREYKNIGHT_STT_URL = saved
      if not text then return fail(err) end
      notify(("Ready: <leader>av speaks to the agent, <leader>aV dictates. The sample: %q"):format(text), vim.log.levels.INFO, { timeout = 10000 })
    end)
  end
  local i = 0
  local function next()
    i = i + 1
    if steps[i] then steps[i](next) end
  end
  next()
end

return M
