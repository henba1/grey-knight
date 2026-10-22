# Helpers for GreyKnight's explorer script slots in PowerShell - the context and Neovim's dialogs (USAGE.md,
# Script slots)
#
#   . (Join-Path $env:GK_LIB 'gk.ps1')
#   $files = Get-GkMarked; if (-not $files) { $files = @($env:GK_CURSOR) }
#   if (Confirm-Gk "Delete $($files.Count) files?") { ... }
#   $name = Read-Gk 'New name:' 'notes.md'          # $null when the dialog was closed
#   $color = Select-Gk 'Color:' @('red', 'green')   # $null when the dialog was closed
#
# Each question is a line on stdout (::gk::...), the answer a line on stdin (lua/config/slots.lua).

[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)

function Get-GkMarked {
  if ($env:GK_MARKED -and (Test-Path -LiteralPath $env:GK_MARKED)) {
    @(Get-Content -LiteralPath $env:GK_MARKED -Encoding UTF8 | Where-Object { $_ -ne '' })
  } else { @($args) }
}

function Send-Gk([string]$Kind, [string]$Text = '') {
  [Console]::Out.WriteLine("::gk::${Kind}::" + ($Text -replace "[`r`n]", ' '))
  [Console]::Out.Flush()
}

function Get-GkAnswer([string]$Kind, [string]$Text) {
  Send-Gk $Kind $Text
  $line = [Console]::In.ReadLine()
  if ($null -eq $line) { '' } else { $line.TrimEnd("`r") }
}

# Yes / No in Neovim: $true for Yes
function Confirm-Gk([string]$Question) { (Get-GkAnswer 'confirm' $Question).Trim().ToLower().StartsWith('y') }

# A text box: the text, or $null when the dialog was closed
function Read-Gk([string]$Prompt, [string]$Default = '') {
  if ($Default) { Send-Gk 'default' $Default }
  $a = Get-GkAnswer 'input' $Prompt
  if ($a -eq '') { $null } else { $a }
}

# A choice: the option, or $null when the dialog was closed
function Select-Gk([string]$Prompt, [string[]]$Options) {
  foreach ($o in $Options) { Send-Gk 'option' $o }
  $a = Get-GkAnswer 'select' $Prompt
  if ($Options -contains $a) { $a } else { $null }
}

function Send-GkNotify([string]$Message) { Send-Gk 'notify' $Message }
function Send-GkWarn([string]$Message) { Send-Gk 'warn' $Message }
function Send-GkError([string]$Message) { Send-Gk 'error' $Message }
function Open-Gk([string]$Path, [int]$Line = 0) { if ($Line -gt 0) { Send-Gk 'open' "${Path}:$Line" } else { Send-Gk 'open' $Path } }
function Update-GkTree { Send-Gk 'refresh' '' }
