$sourcePath = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed.xlsx'
$tempPath = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed_FILTER_TEMP.xlsx'

if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
Copy-Item $sourcePath $tempPath

function Normalize-Text($value) {
    if ($null -eq $value) { return '' }
    $text = [string]$value
    return $text.Trim()
}

function Get-StudentStartupFit($title, $description, $type, $amountText, $cateredToward, $openApp) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $amountText) + ' ' + (Normalize-Text $cateredToward) + ' ' + (Normalize-Text $openApp)).ToLowerInvariant()

    $score = 0
    if ($text -match 'ucsd|campus|university|student|undergraduate|graduate|alumni') { $score += 2 }
    if ($text -match 'grant|funding|prize|award|scholarship|microgrant') { $score += 2 }
    if ($text -match 'prototype|mvp|pilot|traction|revenue|commercial|launch|product') { $score += 2 }
    if ($text -match 'idea|concept|early-stage|pre-seed') { $score += 1 }
    if ($text -match 'accelerator|incubator|cohort|program') { $score += 1 }
    if ($text -match 'network|community|mentor|advising|consulting|resource') { $score += 1 }
    if ($text -match 'venture capital|angel|vc|equity|dilutive|fund') { $score -= 1 }
    if ($text -match 'research|lab|biotech|medtech|deep tech|science|phd') { $score += 1 }

    $amount = Normalize-Text $amountText
    if ($amount -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*\+|\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*k|\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*m|\$\s*\d+') {
        $score += 1
    }

    if ($score -ge 6) { return 'Excellent' }
    if ($score -ge 4) { return 'Strong' }
    if ($score -ge 2) { return 'Moderate' }
    return 'Low'
}

function Get-BestFor($title, $description, $type, $cateredToward) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $cateredToward)).ToLowerInvariant()

    if ($text -match 'research|biotech|medtech|health|scientist|lab|phd|faculty|academic') { return 'Research spinout' }
    if ($text -match 'climate|cleantech|energy|sustainability|environment') { return 'Climate / cleantech' }
    if ($text -match 'social|community|equity|impact|nonprofit|public interest') { return 'Social impact' }
    if ($text -match 'hardware|device|robotics|fabrication|prototype|wet lab|lab access') { return 'Hardware / prototype' }
    if ($text -match 'software|saas|ai|platform|app|digital|cyber') { return 'Software / digital' }
    if ($text -match 'network|mentor|advising|consulting|resource|support|community') { return 'Networking / support' }
    if ($text -match 'accelerator|incubator|cohort|program') { return 'Early-stage team' }
    return 'General startup support'
}

function Get-FounderStage($title, $description, $type, $openApp) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $openApp)).ToLowerInvariant()

    if ($text -match 'idea|concept|pre-seed|early-stage|student project') { return 'Idea' }
    if ($text -match 'prototype|mvp|pilot|beta|product|lab access|fabrication|testing') { return 'Prototype' }
    if ($text -match 'traction|revenue|commercial|scale|growth|launch|series') { return 'Traction' }
    return 'Any stage'
}

function Get-EligibilityLabel($title, $type, $openApp, $description, $generalNotes, $cateredToward) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $openApp) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $generalNotes) + ' ' + (Normalize-Text $cateredToward)).ToLowerInvariant()

    $labels = @()
    if ($text -match 'ucsd|university|campus|school|jacobs|rady|scripps') { $labels += 'UCSD-affiliated' }
    if ($text -match 'student|undergraduate|graduate|current student|student-led|students') { $labels += 'Student-only' }
    if ($text -match 'alumni|recent graduate|postdoc') { $labels += 'Student + alumni' }
    if ($text -match 'open to all|any founder|anyone|global|worldwide|open to students and non-students') { $labels += 'Open to all' }
    if ($text -match 'research|faculty|lab|scientist|academic') { $labels += 'Research / academic' }
    if ($text -match 'regional|state|county|local|community|city|san diego|southern california') { $labels += 'Regional / local' }

    if ($labels.Count -eq 0) { return 'General access' }

    $unique = @()
    foreach ($label in $labels) {
        if (-not ($unique -contains $label)) { $unique += $label }
    }

    return ($unique -join ' / ')
}

function Get-PriorityTier($fit, $valueText) {
    if ($fit -eq 'Excellent') { return 'Tier 1' }
    if ($fit -eq 'Strong') { return 'Tier 2' }
    if ($fit -eq 'Moderate') { return 'Tier 3' }
    return 'Tier 4'
}

function Get-OpportunityTags($title, $description, $type, $cateredToward, $fit) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $cateredToward)).ToLowerInvariant()
    $tags = @()

    if ($type -match 'Grant|Accelerator|Competition|Incubator|Investment|Loan|Network|Service') { $tags += $type }
    if ($text -match 'student|ucsd|undergraduate|graduate') { $tags += 'Student-friendly' }
    if ($text -match 'research|biotech|medtech|science|lab') { $tags += 'Research-heavy' }
    if ($text -match 'climate|cleantech|energy|sustainability') { $tags += 'Climate' }
    if ($text -match 'social|community|equity|impact') { $tags += 'Social impact' }
    if ($text -match 'ai|software|saas|digital') { $tags += 'Software' }
    if ($text -match 'hardware|device|robotics|fabrication|prototype') { $tags += 'Hardware' }
    if ($fit -eq 'Excellent' -or $fit -eq 'Strong') { $tags += 'Priority' }

    if ($tags.Count -eq 0) { return 'General' }

    $unique = @()
    foreach ($tag in $tags) {
        if (-not ($unique -contains $tag)) { $unique += $tag }
    }

    return ($unique -join '; ')
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$wb = $excel.Workbooks.Open($tempPath)
$ws = $wb.Worksheets.Item('Reviewed_2026')

$headers = @(
    'Student Startup Fit',
    'Best For',
    'Founder Stage',
    'Eligibility Label',
    'Opportunity Tags',
    'Priority Tier'
)

$insertAt = 23
for ($i = 0; $i -lt $headers.Count; $i++) {
    $ws.Columns.Item($insertAt).Insert()
    $ws.Cells.Item(1, $insertAt) = $headers[$i]
    $insertAt++
}

$lastRow = $ws.UsedRange.Rows.Count
for ($r = 2; $r -le $lastRow; $r++) {
    $title = $ws.Cells.Item($r, 1).Value2
    $description = $ws.Cells.Item($r, 2).Value2
    $amount = $ws.Cells.Item($r, 3).Value2
    $type = $ws.Cells.Item($r, 4).Value2
    $openApp = $ws.Cells.Item($r, 6).Value2
    $generalNotes = $ws.Cells.Item($r, 11).Value2
    $cateredToward = $ws.Cells.Item($r, 8).Value2

    $fit = Get-StudentStartupFit -title $title -description $description -type $type -amountText $amount -cateredToward $cateredToward -openApp $openApp
    $bestFor = Get-BestFor -title $title -description $description -type $type -cateredToward $cateredToward
    $stage = Get-FounderStage -title $title -description $description -type $type -openApp $openApp
    $eligibility = Get-EligibilityLabel -title $title -type $type -openApp $openApp -description $description -generalNotes $generalNotes -cateredToward $cateredToward
    $tags = Get-OpportunityTags -title $title -description $description -type $type -cateredToward $cateredToward -fit $fit
    $tier = Get-PriorityTier -fit $fit -valueText $amount

    $ws.Cells.Item($r, 23) = $fit
    $ws.Cells.Item($r, 24) = $bestFor
    $ws.Cells.Item($r, 25) = $stage
    $ws.Cells.Item($r, 26) = $eligibility
    $ws.Cells.Item($r, 27) = $tags
    $ws.Cells.Item($r, 28) = $tier
}

$ws.Rows.Item(1).Font.Bold = $true
for ($c = 1; $c -le 28; $c++) {
    $ws.Columns.Item($c).AutoFit()
}

$wb.Save()
Write-Host 'Added filter columns to Reviewed_2026: Student Startup Fit, Best For, Founder Stage, Eligibility Label, Opportunity Tags, Priority Tier'
Write-Host 'Final column count: ' + $ws.UsedRange.Columns.Count

$wb.Close($true)
$excel.Quit()

if (Test-Path $sourcePath) { Remove-Item $sourcePath -Force }
Move-Item $tempPath $sourcePath -Force
