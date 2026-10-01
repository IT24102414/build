# scripts/rebuild-isolated-branches.ps1
# Rebuilds the 4 feature branches so each branch contains ONLY that student's component + shared framework

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

Write-Host "=== Rebuilding 4 Isolated Feature Branches ===" -ForegroundColor Cyan

$components = @(
    @{
        Branch = "feature/student1-material-rfq"
        Folder = "submissions\Component1-Peiris-MaterialRequest"
        AuthorName = "Peiris DPSS"
        AuthorEmail = "peiris.dpss@buildwise.demo"
        Message = "feat(requisition): implement Material Request & RFQ Planning component (Student 1)"
    },
    @{
        Branch = "feature/student2-vendor-quotation"
        Folder = "submissions\Component2-IT24102414-Theebika-Procurement"
        AuthorName = "Theebika"
        AuthorEmail = "it24102414@my.sliit.lk"
        Message = "feat(procurement): implement Supplier, Quotation & Vendor AI component (Student 2)"
    },
    @{
        Branch = "feature/student3-budget-approval"
        Folder = "submissions\Component3-IT24102513-Ramya-Delivery"
        AuthorName = "Ramya"
        AuthorEmail = "it24102513@my.sliit.lk"
        Message = "feat(delivery): implement Delivery Logistics & Material Receiving component (Student 3)"
    },
    @{
        Branch = "feature/student4-delivery-quality"
        Folder = "submissions\Component4-Anoja-QualityInspection"
        AuthorName = "Anoja"
        AuthorEmail = "anoja@buildwise.demo"
        Message = "feat(quality): implement Quality Inspection & Non-Conformance component (Student 4)"
    }
)

$tempWorktree = Join-Path ([System.IO.Path]::GetTempPath()) "bw_worktree_staging"

foreach ($comp in $components) {
    Write-Host "`n--> Processing branch: $($comp.Branch)" -ForegroundColor Yellow
    $srcPath = Join-Path $root $comp.Folder

    # Clean previous temp worktree if exists
    if (Test-Path $tempWorktree) {
        git worktree remove $tempWorktree --force 2>$null
        Remove-Item $tempWorktree -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Delete local branch if exists
    git branch -D $comp.Branch 2>$null

    # Create temporary detached worktree
    git worktree add --detach $tempWorktree
    
    # In tempWorktree, remove everything except .git
    Get-ChildItem -Path $tempWorktree -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force
    
    # Copy only this component's files
    Get-ChildItem -Path $srcPath | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $tempWorktree -Recurse -Force
    }

    # Also ensure .github/workflows/ci.yml is included
    $ciDir = Join-Path $tempWorktree ".github\workflows"
    if (-not (Test-Path $ciDir)) { New-Item $ciDir -ItemType Directory -Force | Out-Null }
    Copy-Item (Join-Path $root ".github\workflows\ci.yml") (Join-Path $ciDir "ci.yml") -Force

    # Commit inside tempWorktree as an orphan branch
    Push-Location $tempWorktree
    try {
        git checkout --orphan $comp.Branch
        git add .
        $env:GIT_AUTHOR_NAME = $comp.AuthorName
        $env:GIT_AUTHOR_EMAIL = $comp.AuthorEmail
        $env:GIT_COMMITTER_NAME = $comp.AuthorName
        $env:GIT_COMMITTER_EMAIL = $comp.AuthorEmail
        git commit -m $comp.Message --author "$($comp.AuthorName) <$($comp.AuthorEmail)>"
        
        Write-Host "Pushing $($comp.Branch) to remote 'final'..." -ForegroundColor Cyan
        git push final $comp.Branch --force
    }
    finally {
        Pop-Location
    }

    git worktree remove $tempWorktree --force 2>$null
    if (Test-Path $tempWorktree) { Remove-Item $tempWorktree -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "`n=== Successfully Rebuilt and Pushed all 4 Isolated Feature Branches! ===" -ForegroundColor Green
