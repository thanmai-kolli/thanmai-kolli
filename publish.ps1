<#
    Publishes the GitHub profile README for the currently authenticated gh user.

    Usage:
        gh auth login --web          # sign in as Thanmai Kolli
        .\publish.ps1

    Optional overrides:
        .\publish.ps1 -LinkedIn "https://www.linkedin.com/in/your-handle/" -Email "you@example.com"
#>

[CmdletBinding()]
param(
    [string]$LinkedIn,
    [string]$Email
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# --- 1. Verify authentication (sign in automatically if needed) ---------------
gh auth status --hostname github.com 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not signed in to GitHub. Launching browser sign-in..." -ForegroundColor Yellow
    Write-Host "Make sure your browser is signed in as Thanmai Kolli before approving." -ForegroundColor Yellow
    gh auth login --hostname github.com --git-protocol https --web --scopes "repo,workflow,read:user,user:email"
    if ($LASTEXITCODE -ne 0) { Fail "GitHub sign-in did not complete." }
}

$login = (gh api user --jq '.login').Trim()
$name  = (gh api user --jq '.name // .login').Trim()
if ([string]::IsNullOrWhiteSpace($login)) { Fail "Could not resolve the authenticated username." }

Write-Host "Authenticated as: $login ($name)" -ForegroundColor Cyan

# --- 2. Personalise the README ------------------------------------------------
$readmePath = Join-Path $root 'README.md'
$readme = Get-Content $readmePath -Raw

$readme = $readme -replace 'USERNAME', $login
$readme = $readme -replace '\]\(https://github\.com/\)', "](https://github.com/$login)"

if ($LinkedIn) { $readme = $readme -replace '\]\(https://www\.linkedin\.com/\)', "]($LinkedIn)" }
if ($Email)    { $readme = $readme -replace '\]\(mailto:\)', "](mailto:$Email)" }

Set-Content -Path $readmePath -Value $readme -Encoding UTF8 -NoNewline
Write-Host "README personalised for '$login'." -ForegroundColor Green

# --- 3. Create the profile repository if it does not exist --------------------
gh repo view "$login/$login" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating profile repository $login/$login ..." -ForegroundColor Cyan
    gh repo create "$login/$login" --public --description "My GitHub profile README" | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "Failed to create repository $login/$login." }
} else {
    Write-Host "Repository $login/$login already exists - pushing into it." -ForegroundColor Yellow
}

# --- 4. Initialise git and push ----------------------------------------------
Push-Location $root
try {
    if (-not (Test-Path (Join-Path $root '.git'))) { git init -b main | Out-Null }

    git config user.name  $name
    git config user.email "$login@users.noreply.github.com"

    git remote remove origin 2>&1 | Out-Null
    git remote add origin "https://github.com/$login/$login.git"

    git add -A
    git commit -m "Add GitHub profile README" 2>&1 | Out-Null

    gh auth setup-git --hostname github.com | Out-Null
    git push -u origin main --force
    if ($LASTEXITCODE -ne 0) { Fail "Push failed." }
}
finally { Pop-Location }

Write-Host ""
Write-Host "Done. Your profile is live at https://github.com/$login" -ForegroundColor Green
Write-Host "Tip: run the 'Generate snake animation' workflow once from the Actions tab to render the contribution snake." -ForegroundColor DarkGray
