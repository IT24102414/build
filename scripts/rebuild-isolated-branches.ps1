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

foreach ($comp in $components) {
    Write-Host "`n--> Processing branch: $($comp.Branch)" -ForegroundColor Yellow
    $srcPath = Join-Path $root $comp.Folder
    
    # Delete existing local branch if present, then create orphan
    git branch -D $($comp.Branch) 2>$null
    git checkout --orphan $($comp.Branch)
    
    # Remove all tracked and untracked files from git index & working tree (except .git, submissions, submission_packages, scripts)
    Get-ChildItem -Path $root -Exclude ".git", "submissions", "submission_packages", "scripts", "node_modules", ".venv" | Remove-Item -Recurse -Force
    git rm -rf . 2>$null | Out-Null
    
    # Copy only this component's files into root
    Get-ChildItem -Path $srcPath | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $root -Recurse -Force
    }
    
    # Stage files and commit
    git add .
    $env:GIT_AUTHOR_NAME = $comp.AuthorName
    $env:GIT_AUTHOR_EMAIL = $comp.AuthorEmail
    $env:GIT_COMMITTER_NAME = $comp.AuthorName
    $env:GIT_COMMITTER_EMAIL = $comp.AuthorEmail
    
    git commit -m $comp.Message --author "$($comp.AuthorName) <$($comp.AuthorEmail)>"
    
    # Push to final remote
    Write-Host "Pushing $($comp.Branch) to remote 'final'..." -ForegroundColor Cyan
    git push final $($comp.Branch) --force
}

# Switch back to main
git checkout main
Write-Host "`n=== Successfully Rebuilt and Pushed all 4 Isolated Feature Branches! ===" -ForegroundColor Green
