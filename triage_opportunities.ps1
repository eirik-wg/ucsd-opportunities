$source = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed.xlsx'

function Normalize-Text($value) {
    if ($null -eq $value) { return '' }
    return ([string]$value).Trim()
}

function Get-EligibilityLabel($title, $type, $openApp, $description, $generalNotes, $cateredToward) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $openApp) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $generalNotes) + ' ' + (Normalize-Text $cateredToward)).ToLowerInvariant()

    $labels = @()

    if ($text -match 'ucsd|university|campus|school') { $labels += 'UCSD-affiliated' }
    if ($text -match 'student|undergraduate|graduate|current student|student-led|student founder|students') { $labels += 'Student-only' }
    if ($text -match 'alumni|recent graduate|postdoc') { $labels += 'Student + alumni' }
    if ($text -match 'open to all|any founder|all founders|anyone|global|worldwide|open to students and non-students') { $labels += 'Open to all' }
    if ($text -match 'idea|early-stage|concept|pre-seed|prototype|pilot|product stage') { $labels += 'Idea-stage' }
    if ($text -match 'mvp|traction|revenue|commercial|pilot|prototype|launch') { $labels += 'Prototype / traction' }
    if ($text -match 'health|engineering|design|life sciences|climate|social innovation|community|specific industry|medtech|deep tech|ai|biotech') { $labels += 'Industry-specific' }
    if ($text -match 'research|faculty|lab|scientist|academic') { $labels += 'Research / academic' }
    if ($text -match 'regional|state|county|local|community|city|baylor|ucsd|san diego') { $labels += 'Regional / local' }

    if ($labels.Count -eq 0) { $labels += 'General access' }

    $unique = @()
    foreach ($label in $labels) {
        if (-not ($unique -contains $label)) { $unique += $label }
    }

    return ($unique -join ' / ')
}

function Get-ExpectedValue($amountText) {
    $text = (Normalize-Text $amountText).ToLowerInvariant()
    if ($text -match 'no cash|free services|no prize|free access|service') { return 'Low value: non-cash support' }
    if ($text -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*(k|m|thousand|million)') {
        $raw = $text
        $value = 0
        if ($raw -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*k') { $value = [double]($Matches[1]) * 1000 }
        elseif ($raw -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*m') { $value = [double]($Matches[1]) * 1000000 }
        elseif ($raw -match 'up to \$\s*(\d+(?:,\d{3})*(?:\.\d+)?)') { $value = [double]($Matches[1]) }
        if ($value -ge 100000) { return '$100K+' }
        if ($value -ge 25000) { return '$25K-$100K' }
        if ($value -ge 5000) { return '$5K-$25K' }
        if ($value -ge 1000) { return '$1K-$5K' }
        return '$0-$1K' }

    if ($text -match 'varies|typically|depends|rolling|annual|cycle|up to|prizes vary|project stipends') { return 'Variable/typical support' }

    return 'Not stated'
}

function Get-ValueNumeric($amountText) {
    $text = (Normalize-Text $amountText).ToLowerInvariant()
    if ($text -match 'no cash|free services|free access|gratis|service') { return 2 }
    if ($text -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*k') {
        $value = [double]($Matches[1]) * 1000
        return $value
    }
    if ($text -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*m') {
        $value = [double]($Matches[1]) * 1000000
        return $value
    }
    if ($text -match 'up to \$\s*(\d+(?:,\d{3})*(?:\.\d+)?)') {
        return [double]($Matches[1])
    }
    if ($text -match 'varies|typically|depends|rolling|annual|cycle') { return 15000 }
    return 2000
}

function Get-SuccessChance($type, $eligibility, $title, $openApp, $amountText) {
    $t = (Normalize-Text $type).ToLowerInvariant()
    $elig = (Normalize-Text $eligibility).ToLowerInvariant()
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $openApp)).ToLowerInvariant()

    $base = 12
    if ($t -match 'grant') { $base = 18 }
    elseif ($t -match 'competition') { $base = 14 }
    elseif ($t -match 'accelerator') { $base = 10 }
    elseif ($t -match 'incubator') { $base = 13 }
    elseif ($t -match 'investment|fund') { $base = 8 }
    elseif ($t -match 'support|program') { $base = 20 }

    $access = 0
    if ($elig -match 'ucsd-affiliated|student-only') { $access = 18 }
    elseif ($elig -match 'student \+ alumni|open to all') { $access = 12 }
    elseif ($elig -match 'industry-specific|research / academic|regional / local') { $access = 9 }
    else { $access = 10 }

    $stage = 0
    if ($text -match 'idea|early-stage|prototype|concept|pre-seed|startup') { $stage = 12 }
    elseif ($text -match 'traction|mvp|pilot|commercial|revenue') { $stage = 9 }
    else { $stage = 8 }

    $amount = Get-ValueNumeric $amountText
    $valueScore = 0
    if ($amount -ge 100000) { $valueScore = 10 }
    elseif ($amount -ge 25000) { $valueScore = 8 }
    elseif ($amount -ge 5000) { $valueScore = 6 }
    elseif ($amount -ge 1000) { $valueScore = 4 }
    else { $valueScore = 2 }

    $total = $base + $access + $stage + $valueScore
    $chance = [Math]::Min(85, [Math]::Max(8, $total))
    return [int]$chance
}

function Get-TriageScore($successChance, $eligibility, $amountText, $type, $title) {
    $eligText = (Normalize-Text $eligibility).ToLowerInvariant()
    $eligibilityWeight = 0
    if ($eligText -match 'ucsd-affiliated|student-only') { $eligibilityWeight = 30 }
    elseif ($eligText -match 'student \+ alumni|open to all') { $eligibilityWeight = 22 }
    elseif ($eligText -match 'industry-specific|research / academic|regional / local') { $eligibilityWeight = 17 }
    else { $eligibilityWeight = 14 }

    $amountValue = 0
    $amount = Get-ValueNumeric $amountText
    if ($amount -ge 100000) { $amountValue = 24 }
    elseif ($amount -ge 25000) { $amountValue = 20 }
    elseif ($amount -ge 5000) { $amountValue = 15 }
    elseif ($amount -ge 1000) { $amountValue = 10 }
    else { $amountValue = 6 }

    $realism = 0
    if ($eligText -match 'ucsd-affiliated|student-only') { $realism = 18 }
    elseif ($eligText -match 'open to all') { $realism = 12 }
    else { $realism = 14 }

    if ((Normalize-Text $type).ToLowerInvariant() -match 'grant|support') { $realism += 8 }
    if ((Normalize-Text $title).ToLowerInvariant() -match 'rolling|open application|annual') { $realism += 4 }

    $score = [Math]::Min(100, [Math]::Round(($eligibilityWeight * 0.34) + ($amountValue * 0.26) + ($realism * 0.22) + (($successChance * 0.18))))
    return [int]$score
}

function Get-Tier($score) {
    if ($score -ge 80) { return 'Tier 1: Highest priority' }
    if ($score -ge 65) { return 'Tier 2: Strong option' }
    if ($score -ge 50) { return 'Tier 3: Moderate fit' }
    return 'Tier 4: Secondary / low-priority'
}

function Get-Rationale($title, $type, $eligibility, $amountText, $successChance, $isEligible) {
    $titleClean = Normalize-Text $title
    $typeClean = (Normalize-Text $type)
    $eligClean = Normalize-Text $eligibility
    $amountClean = Normalize-Text $amountText
    $chance = [int]$successChance
    if ($isEligible) {
        $fit = 'good fit for UCSD startups'
    }
    else {
        $fit = 'less aligned with a typical UCSD founding path'
    }
    return "$titleClean is a $typeClean opportunity with $eligClean eligibility. The opportunity is $fit, has a plausible success range of about $chance%, and a typical value profile of $amountClean."
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($source)

# Remove any prior triage sheet to keep it fresh.
foreach ($sheet in $wb.Worksheets) {
    if ($sheet.Name -eq 'Triage_2026') {
        $sheet.Delete()
        break
    }
}

$sheet = $wb.Worksheets.Add()
$sheet.Name = 'Triage_2026'

$wsMain = $wb.Worksheets.Item('Reviewed_2026')
$rows = @()

for ($r = 2; $r -le $wsMain.UsedRange.Rows.Count; $r++) {
    $title = Normalize-Text $wsMain.Cells.Item($r, 1).Value2
    if ([string]::IsNullOrWhiteSpace($title)) { continue }

    $description = Normalize-Text $wsMain.Cells.Item($r, 2).Value2
    $amountText = Normalize-Text $wsMain.Cells.Item($r, 3).Value2
    $type = Normalize-Text $wsMain.Cells.Item($r, 4).Value2
    $openApp = Normalize-Text $wsMain.Cells.Item($r, 6).Value2
    $cateredToward = Normalize-Text $wsMain.Cells.Item($r, 8).Value2
    $generalNotes = Normalize-Text $wsMain.Cells.Item($r, 11).Value2

    $eligibility = Get-EligibilityLabel -title $title -type $type -openApp $openApp -description $description -generalNotes $generalNotes -cateredToward $cateredToward
    $expectedValue = Get-ExpectedValue $amountText
    $successChance = Get-SuccessChance -type $type -eligibility $eligibility -title $title -openApp $openApp -amountText $amountText
    $triageScore = Get-TriageScore -successChance $successChance -eligibility $eligibility -amountText $amountText -type $type -title $title
    $tier = Get-Tier $triageScore
    $isEligible = ($eligibility -match 'ucsd-affiliated|student-only|student \+ alumni') -or ($openApp -match 'student|ucsd|undergraduate|graduate')
    $rationale = Get-Rationale -title $title -type $type -eligibility $eligibility -amountText $amountText -successChance $successChance -isEligible $isEligible

    $rows += [pscustomobject]@{
        Title = $title
        Type = $type
        EligibilityLabel = $eligibility
        CriteriaSummary = if ($openApp) { $openApp } else { 'No explicit criteria captured in the source dataset' }
        SuccessChance = [string]$successChance + '%'
        ExpectedValue = $expectedValue
        TriageScore = $triageScore
        Tier = $tier
        Rationale = $rationale
    }
}

$rows = $rows | Sort-Object -Property TriageScore -Descending

$headers = @('Rank', 'Program Title', 'Type', 'Eligibility Label', 'Eligibility Criteria', 'Success Chance', 'Expected Monetary Value', 'Triage Score', 'Priority Tier', 'Triage Rationale')

for ($i = 0; $i -lt $headers.Count; $i++) {
    $sheet.Cells.Item(1, $i + 1) = $headers[$i]
}

$sheet.Cells.Item(1, 1).Font.Bold = $true
$sheet.Cells.Item(1, 1).Interior.Color = 0xD9EAF7

for ($idx = 0; $idx -lt $rows.Count; $idx++) {
    $row = $rows[$idx]
    $r = $idx + 2
    $sheet.Cells.Item($r, 1) = $idx + 1
    $sheet.Cells.Item($r, 2) = $row.Title
    $sheet.Cells.Item($r, 3) = $row.Type
    $sheet.Cells.Item($r, 4) = $row.EligibilityLabel
    $sheet.Cells.Item($r, 5) = $row.CriteriaSummary
    $sheet.Cells.Item($r, 6) = $row.SuccessChance
    $sheet.Cells.Item($r, 7) = $row.ExpectedValue
    $sheet.Cells.Item($r, 8) = $row.TriageScore
    $sheet.Cells.Item($r, 9) = $row.Tier
    $sheet.Cells.Item($r, 10) = $row.Rationale
}

# Add an explanatory rubric block in the top-left area.
$sheet.Cells.Item(1, 13) = 'Eligibility labels used'
$sheet.Cells.Item(2, 13) = 'UCSD-affiliated'
$sheet.Cells.Item(3, 13) = 'Student-only'
$sheet.Cells.Item(4, 13) = 'Student + alumni'
$sheet.Cells.Item(5, 13) = 'Open to all'
$sheet.Cells.Item(6, 13) = 'Idea-stage'
$sheet.Cells.Item(7, 13) = 'Prototype / traction'
$sheet.Cells.Item(8, 13) = 'Industry-specific'
$sheet.Cells.Item(9, 13) = 'Research / academic'
$sheet.Cells.Item(10, 13) = 'Regional / local'

$sheet.Cells.Item(1, 14) = 'Meaning'
$sheet.Cells.Item(2, 14) = 'UCSD students, labs, or campus affiliations'
$sheet.Cells.Item(3, 14) = 'Current student founders or campus-based teams'
$sheet.Cells.Item(4, 14) = 'Recent grads or alumni included'
$sheet.Cells.Item(5, 14) = 'Broad access, not restricted by university status'
$sheet.Cells.Item(6, 14) = 'Concept-stage and idea-stage founders'
$sheet.Cells.Item(7, 14) = 'MVP, pilot, or traction stage'
$sheet.Cells.Item(8, 14) = 'Specific sectors or disciplines only'
$sheet.Cells.Item(9, 14) = 'Academic or research-led path'
$sheet.Cells.Item(10, 14) = 'Local or regional organizations only'

foreach ($col in 1..10) {
    $sheet.Columns.Item($col).AutoFit()
}
for ($col = 13; $col -le 14; $col++) {
    $sheet.Columns.Item($col).AutoFit()
}
$sheet.Rows.Item(1).Font.Bold = $true

$sheet.Range('A1:J1').Interior.Color = 0xD9EAF7
$sheet.Range('M1:N1').Interior.Color = 0xE2F0D9

$wb.Save()
Write-Host ('Rows scored: ' + $rows.Count)
Write-Host ('Top 10 titles:')
for ($i = 0; $i -lt [Math]::Min(10, $rows.Count); $i++) {
    $row = $rows[$i]
    Write-Host (($i + 1).ToString() + '. ' + $row.Title + ' | score=' + $row.TriageScore + ' | chance=' + $row.SuccessChance + ' | value=' + $row.ExpectedValue)
}

$wb.Close($true)
$excel.Quit()
