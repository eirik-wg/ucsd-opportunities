$source = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed.xlsx'
$target = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_triage.xlsx'

function Normalize-Text($value) {
    if ($null -eq $value) { return '' }
    return ([string]$value).Trim()
}

function Get-AmountValue($amountText) {
    $text = (Normalize-Text $amountText).ToLowerInvariant()
    if ($text -match 'no cash|free services|free access|gratis|service|no prize') { return 0 }
    if ($text -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*k') { return [double]($Matches[1]) * 1000 }
    if ($text -match '\$\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*m') { return [double]($Matches[1]) * 1000000 }
    if ($text -match 'up to \$\s*(\d+(?:,\d{3})*(?:\.\d+)?)') { return [double]($Matches[1]) }
    if ($text -match 'varies|typically|depends|rolling|annual|cycle|project stipends|prizes vary') { return 15000 }
    return 2000
}

function Get-ExpectedValue($amountText) {
    $value = Get-AmountValue $amountText
    if ($value -eq 0) { return 'Non-cash support' }
    if ($value -ge 100000) { return '$100K+' }
    if ($value -ge 25000) { return '$25K-$100K' }
    if ($value -ge 5000) { return '$5K-$25K' }
    if ($value -ge 1000) { return '$1K-$5K' }
    return '$0-$1K'
}

function Get-EligibilityLabel($title, $type, $openApp, $description, $generalNotes, $cateredToward) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $openApp) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $generalNotes) + ' ' + (Normalize-Text $cateredToward)).ToLowerInvariant()

    $labels = @()
    if ($text -match 'ucsd|university|campus|school') { $labels += 'UCSD-affiliated' }
    if ($text -match 'student|undergraduate|graduate|current student|student-led|student founder|students') { $labels += 'Student-only' }
    if ($text -match 'alumni|recent graduate|postdoc') { $labels += 'Student + alumni' }
    if ($text -match 'open to all|any founder|anyone|global|worldwide|open to students and non-students') { $labels += 'Open to all' }
    if ($text -match 'idea|early-stage|concept|pre-seed|prototype|pilot|startup stage') { $labels += 'Idea-stage' }
    if ($text -match 'mvp|traction|revenue|commercial|pilot|launch') { $labels += 'Prototype / traction' }
    if ($text -match 'health|engineering|design|life sciences|climate|social innovation|community|specific industry|medtech|deep tech|ai|biotech') { $labels += 'Industry-specific' }
    if ($text -match 'research|faculty|lab|scientist|academic') { $labels += 'Research / academic' }
    if ($text -match 'regional|state|county|local|community|city|baylor|san diego') { $labels += 'Regional / local' }

    if ($labels.Count -eq 0) { return 'General access' }

    $unique = @()
    foreach ($label in $labels) {
        if (-not ($unique -contains $label)) { $unique += $label }
    }
    return ($unique -join ' / ')
}

function Get-UCSDFitScore($title, $type, $openApp, $description, $amountText) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $openApp) + ' ' + (Normalize-Text $description)).ToLowerInvariant()
    $score = 10

    if ($text -match 'ucsd|campus|university') { $score += 20 }
    elseif ($text -match 'student|undergraduate|graduate|alumni') { $score += 16 }
    elseif ($text -match 'open to all|global|any founder') { $score += 6 }
    else { $score += 8 }

    if ($text -match 'non-dilutive|grant|support|program') { $score += 8 }
    if ($text -match 'idea|prototype|pilot|early-stage|concept') { $score += 5 }
    if ($text -match 'vc|venture capital|equity|dilutive|fund') { $score -= 10 }
    if ($text -match 'national|international|competition') { $score -= 4 }

    $amount = Get-AmountValue $amountText
    if ($amount -ge 25000) { $score += 6 }
    elseif ($amount -ge 5000) { $score += 4 }
    elseif ($amount -eq 0) { $score += 5 }

    return [int]([Math]::Min(40, [Math]::Max(5, $score)))
}

function Get-SuccessChance($title, $type, $openApp, $eligibility, $amountText) {
    $text = ((Normalize-Text $title) + ' ' + (Normalize-Text $type) + ' ' + (Normalize-Text $openApp)).ToLowerInvariant()
    $amount = Get-AmountValue $amountText

    $score = 18
    if ($type -match 'Grant|grant') { $score += 12 }
    elseif ($type -match 'Support|support|Program|program') { $score += 14 }
    elseif ($type -match 'Competition|competition') { $score += 8 }
    elseif ($type -match 'Accelerator|accelerator|Incubator|incubator') { $score += 6 }
    elseif ($type -match 'Investment|investment|Fund|fund') { $score += 2 }

    if ($eligibility -match 'UCSD-affiliated|Student-only') { $score += 16 }
    elseif ($eligibility -match 'Student \+ alumni|Open to all') { $score += 10 }
    else { $score += 7 }

    if ($text -match 'rolling|annual|open application|simple') { $score += 8 }
    if ($text -match 'pitch|finals|judging|selection|highly selective|competition') { $score -= 6 }
    if ($text -match 'idea|concept|early-stage') { $score += 4 }
    if ($amount -ge 100000) { $score += 2 }
    elseif ($amount -ge 25000) { $score += 4 }
    elseif ($amount -ge 5000) { $score += 6 }
    elseif ($amount -eq 0) { $score += 8 }

    return [int]([Math]::Min(85, [Math]::Max(12, $score)))
}

function Get-TriageScore($ucsdFit, $successChance, $amountText) {
    $amount = Get-AmountValue $amountText
    $amountValue = 0
    if ($amount -ge 100000) { $amountValue = 25 }
    elseif ($amount -ge 25000) { $amountValue = 20 }
    elseif ($amount -ge 5000) { $amountValue = 15 }
    elseif ($amount -ge 1000) { $amountValue = 10 }
    elseif ($amount -eq 0) { $amountValue = 12 }
    else { $amountValue = 8 }

    $score = [Math]::Round(($ucsdFit * 0.45) + ($amountValue * 0.25) + (($successChance * 0.22)) + 8)
    return [int]([Math]::Min(100, [Math]::Max(15, $score)))
}

function Get-Tier($score) {
    if ($score -ge 80) { return 'Tier 1: Highest priority' }
    if ($score -ge 65) { return 'Tier 2: Strong option' }
    if ($score -ge 50) { return 'Tier 3: Moderate fit' }
    return 'Tier 4: Secondary / low-priority'
}

function Get-Rationale($title, $type, $eligibility, $amountText, $successChance, $ucsdFit, $score) {
    $amountLabel = Get-ExpectedValue $amountText
    return "$title is a $type opportunity with $eligibility eligibility. UCSD-fit score: $ucsdFit / 40; success chance: about $successChance%; expected value: $amountLabel; overall ranking score: $score/100."
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
if (Test-Path $target) { Remove-Item $target -Force }
$sourceBook = $excel.Workbooks.Open($source)
$targetBook = $excel.Workbooks.Add()
$ws = $targetBook.Worksheets.Item(1)
$ws.Name = 'Triage_2026'

$headers = @('Rank', 'Program Title', 'Type', 'Eligibility Label', 'Eligibility Criteria', 'Success Chance', 'Expected Monetary Value', 'UCSD Fit Score', 'Triage Score', 'Priority Tier', 'Triage Rationale')
for ($i = 0; $i -lt $headers.Count; $i++) {
    $ws.Cells.Item(1, $i + 1) = $headers[$i]
}
$ws.Rows.Item(1).Font.Bold = $true
$ws.Range('A1:K1').Interior.Color = 0xD9EAF7

$data = @()
$sourceSheet = $sourceBook.Worksheets.Item('Reviewed_2026')
for ($rowIndex = 2; $rowIndex -le $sourceSheet.UsedRange.Rows.Count; $rowIndex++) {
    $title = Normalize-Text $sourceSheet.Cells.Item($rowIndex, 1).Value2
    if ([string]::IsNullOrWhiteSpace($title)) { continue }

    $description = Normalize-Text $sourceSheet.Cells.Item($rowIndex, 2).Value2
    $amountText = Normalize-Text $sourceSheet.Cells.Item($rowIndex, 3).Value2
    $type = Normalize-Text $sourceSheet.Cells.Item($rowIndex, 4).Value2
    $openApp = Normalize-Text $sourceSheet.Cells.Item($rowIndex, 6).Value2
    $generalNotes = Normalize-Text $sourceSheet.Cells.Item($rowIndex, 11).Value2
    $cateredToward = Normalize-Text $sourceSheet.Cells.Item($rowIndex, 8).Value2

    $eligibility = Get-EligibilityLabel -title $title -type $type -openApp $openApp -description $description -generalNotes $generalNotes -cateredToward $cateredToward
    $ucsdFit = Get-UCSDFitScore -title $title -type $type -openApp $openApp -description $description -amountText $amountText
    $successChance = Get-SuccessChance -title $title -type $type -openApp $openApp -eligibility $eligibility -amountText $amountText
    $score = Get-TriageScore -ucsdFit $ucsdFit -successChance $successChance -amountText $amountText
    $tier = Get-Tier $score
    $criteria = if ($openApp) { $openApp } else { 'No explicit restriction captured in source data' }
    $rationale = Get-Rationale -title $title -type $type -eligibility $eligibility -amountText $amountText -successChance $successChance -ucsdFit $ucsdFit -score $score

    $data += [pscustomobject]@{
        Title = $title
        Type = $type
        EligibilityLabel = $eligibility
        CriteriaSummary = $criteria
        SuccessChance = $successChance
        ExpectedValue = Get-ExpectedValue $amountText
        UCSDFit = $ucsdFit
        TriageScore = $score
        Tier = $tier
        Rationale = $rationale
    }
}

$data = $data | Sort-Object -Property TriageScore -Descending

for ($idx = 0; $idx -lt $data.Count; $idx++) {
    $row = $data[$idx]
    $targetRow = $idx + 2
    $ws.Cells.Item($targetRow, 1) = $idx + 1
    $ws.Cells.Item($targetRow, 2) = $row.Title
    $ws.Cells.Item($targetRow, 3) = $row.Type
    $ws.Cells.Item($targetRow, 4) = $row.EligibilityLabel
    $ws.Cells.Item($targetRow, 5) = $row.CriteriaSummary
    $ws.Cells.Item($targetRow, 6).Value2 = [double]($row.SuccessChance / 100.0)
    $ws.Cells.Item($targetRow, 6).NumberFormat = '0%'
    $ws.Cells.Item($targetRow, 7) = $row.ExpectedValue
    $ws.Cells.Item($targetRow, 8) = $row.UCSDFit
    $ws.Cells.Item($targetRow, 9) = $row.TriageScore
    $ws.Cells.Item($targetRow, 10) = $row.Tier
    $ws.Cells.Item($targetRow, 11) = $row.Rationale
}

for ($col = 1; $col -le 11; $col++) {
    $ws.Columns.Item($col).AutoFit()
}

$targetBook.SaveAs($target)
Write-Host ('Rows scored: ' + $data.Count)
Write-Host ('Top 10:')
for ($i = 0; $i -lt [Math]::Min(10, $data.Count); $i++) {
    $row = $data[$i]
    Write-Host (($i + 1).ToString() + '. ' + $row.Title + ' | score=' + $row.TriageScore + ' | fit=' + $row.UCSDFit + ' | success=' + $row.SuccessChance + '% | value=' + $row.ExpectedValue)
}

$targetBook.Close($true)
$sourceBook.Close($false)
$excel.Quit()
