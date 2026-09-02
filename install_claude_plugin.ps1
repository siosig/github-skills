#Requires -Version 7.0
<#
.SYNOPSIS
    Installs the github-skills Claude Code plugin from this repository (Windows).

.DESCRIPTION
    PowerShell port of install_claude_plugin.sh:
      1. Checks required commands (git, claude).
      2. Registers this directory as a local plugin marketplace,
         re-registering it when the known path is stale.
      3. Uninstalls any existing github-skills plugin.
      4. Installs github-skills from the local marketplace.

.NOTES
    Override the marketplace name with the GITHUB_SKILLS_MARKETPLACE_NAME
    environment variable (default: github-skills-local).
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PluginDir       = $PSScriptRoot
$MarketplaceName = if ($env:GITHUB_SKILLS_MARKETPLACE_NAME) { $env:GITHUB_SKILLS_MARKETPLACE_NAME } else { 'github-skills-local' }
$PluginName      = 'github-skills'

# On Windows the claude CLI prints ">" instead of the Unicode pointer; accept both.
$PointerPattern = '[>❯]'

function Test-RequiredCommand {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Hint = ''
    )
    $command = Get-Command -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        [Console]::Error.WriteLine("ERROR: '$Name' not found. Please install it and try again.")
        if ($Hint) { [Console]::Error.WriteLine("       $Hint") }
        exit 1
    }
    $location = if ($command.Source) { $command.Source } else { $command.Name }
    Write-Host "✓ ${Name}: ${location}"
}

function Invoke-Claude {
    param([Parameter(Mandatory)][string[]]$Arguments)
    & claude @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "'claude $($Arguments -join ' ')' failed with exit code ${LASTEXITCODE}."
    }
}

function Get-ClaudeOutput {
    param([Parameter(Mandatory)][string[]]$Arguments)
    # PowerShell 7.0/7.1 turn redirected native stderr into a terminating error
    # under ErrorActionPreference=Stop; relax it for this query-only call.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & claude @Arguments 2>$null
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($LASTEXITCODE -ne 0 -or $null -eq $output) { return @() }
    return @($output)
}

function Get-NormalizedPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    try   { $full = [System.IO.Path]::GetFullPath($Path) }
    catch { $full = $Path }
    return ($full -replace '/', '\').TrimEnd('\')
}

$previousOutputEncoding = [Console]::OutputEncoding
try {
    # The claude CLI (Node.js) writes UTF-8 to pipes; decode it correctly.
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # ── 1. Check required commands ────────────────────────────────────────────
    Test-RequiredCommand -Name 'git'    -Hint 'https://git-scm.com/downloads'
    Test-RequiredCommand -Name 'claude' -Hint 'https://claude.ai/code'

    # ── 2. Register marketplace ───────────────────────────────────────────────
    $KnownMarketplacesFile = Join-Path $HOME '.claude' 'plugins' 'known_marketplaces.json'
    $RegisteredPath = ''
    if (Test-Path -LiteralPath $KnownMarketplacesFile -PathType Leaf) {
        try {
            $known = Get-Content -LiteralPath $KnownMarketplacesFile -Raw | ConvertFrom-Json -AsHashtable
            $entry = if ($known -is [System.Collections.IDictionary]) { $known[$MarketplaceName] } else { $null }
            if ($entry -is [System.Collections.IDictionary] -and
                $entry['source'] -is [System.Collections.IDictionary] -and
                $entry['source']['path']) {
                $RegisteredPath = [string]$entry['source']['path']
            }
        }
        catch {
            $RegisteredPath = ''
        }
    }

    $marketplaceLines = Get-ClaudeOutput -Arguments @('plugin', 'marketplace', 'list')
    $isRegistered = [bool]($marketplaceLines -match "^\s*${PointerPattern} $([regex]::Escape($MarketplaceName))(\s|$)")

    if ($isRegistered) {
        $staleRegistration = $RegisteredPath -ne '' -and
            (Get-NormalizedPath $RegisteredPath) -ne (Get-NormalizedPath $PluginDir)
        if ($staleRegistration) {
            Write-Host "→ marketplace '${MarketplaceName}' points at stale path: ${RegisteredPath}"
            Write-Host "→ re-registering marketplace '${MarketplaceName}': ${PluginDir}"
            Invoke-Claude -Arguments @('plugin', 'marketplace', 'remove', $MarketplaceName)
            Invoke-Claude -Arguments @('plugin', 'marketplace', 'add', $PluginDir)
            Write-Host "✓ marketplace '${MarketplaceName}': re-registered"
        }
        else {
            Write-Host "✓ marketplace '${MarketplaceName}': already registered"
        }
    }
    else {
        Write-Host "→ registering marketplace '${MarketplaceName}': ${PluginDir}"
        Invoke-Claude -Arguments @('plugin', 'marketplace', 'add', $PluginDir)
        Write-Host "✓ marketplace '${MarketplaceName}': registered"
    }

    # ── 3. Remove existing installation ───────────────────────────────────────
    $pluginLines = Get-ClaudeOutput -Arguments @('plugin', 'list')
    $isInstalled = [bool]($pluginLines -match "${PointerPattern} $([regex]::Escape($PluginName))@")

    if ($isInstalled) {
        Write-Host "→ uninstalling existing '${PluginName}' plugin"
        Invoke-Claude -Arguments @('plugin', 'uninstall', $PluginName, '--yes')
        Write-Host "✓ '${PluginName}': uninstalled"
    }
    else {
        Write-Host "✓ '${PluginName}': not installed (skip uninstall)"
    }

    # ── 4. Install plugin ─────────────────────────────────────────────────────
    Write-Host "→ installing '${PluginName}@${MarketplaceName}'"
    Invoke-Claude -Arguments @('plugin', 'install', "${PluginName}@${MarketplaceName}")
    Write-Host "✓ '${PluginName}@${MarketplaceName}': installed"

    Write-Host ''
    Write-Host 'Installation complete. Restart Claude Code to activate the plugin.'
}
catch {
    [Console]::Error.WriteLine("ERROR: $($_.Exception.Message)")
    exit 1
}
finally {
    [Console]::OutputEncoding = $previousOutputEncoding
}
