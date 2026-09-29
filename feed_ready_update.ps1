$sourcePath = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed.xlsx'
$outputPath = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_feed_ready.xlsx'

function Normalize-Text($value) {
    if ($null -eq $value) { return '' }
    return ([string]$value).Trim()
}

function Normalize-Type($title, $description, $currentType) {
    $combined = ((Normalize-Text $title) + ' ' + (Normalize-Text $description) + ' ' + (Normalize-Text $currentType)).ToLowerInvariant()

    if ($combined -match 'loan|microloan|cdfi|lending|sba 7\(a\)|sba 504|loan guarantee') { return 'Loan' }
    if ($combined -match 'angel|vc|venture fund|seed fund|investment|invests|investing|capital') { return 'Investment' }
    if ($combined -match 'competition|contest|pitch competition|challenge|hackathon|summit|finals') { return 'Competition' }
    if ($combined -match 'accelerator|cohort|pre-accelerator|launch program|startup accelerator|accelerator program') { return 'Accelerator' }
    if ($combined -match 'incubator|coworking|lab access|wet lab|workspace|innovation district|hub') { return 'Incubator' }
    if ($combined -match 'grant|scholarship|award|prize|fellowship|stipend|funding') { return 'Grant' }
    if ($combined -match 'network|association|chapter|community|peer group|club|forum|membership') { return 'Network' }
    if ($combined -match 'service|support|advising|consulting|mentoring|resources|licensing|ip protection|technology transfer|legal support|resource hub') { return 'Service' }

    if ($currentType -match 'Grant|Accelerator|Competition|Incubator|Investment|Loan|Network|Service') { return $currentType }
    return 'Service'
}

function Get-HeaderMap() {
    return @(
        'Program Title',
        'Program Description',
        'Funding Amount/Prize Amount',
        'Type',
        'Visit Website',
        'Open Application',
        'Deadline',
        'Catered Toward',
        'Recurring',
        'Characteristics',
        'General Notes',
        'Additional documents',
        'Website link',
        'UCSD Run',
        '2025 Review Notes',
        'Status',
        '2026 Review Notes',
        'Next Review Date',
        'Review Log',
        'Next Deadline',
        'Estimated Deadline Date',
        'Deadline Date Rationale'
    )
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$sourceBook = $excel.Workbooks.Open($sourcePath)
$sourceSheet = $sourceBook.Worksheets.Item('Reviewed_2026')

if (Test-Path $outputPath) { Remove-Item $outputPath -Force }
$targetBook = $excel.Workbooks.Add()
$feedSheet = $targetBook.Worksheets.Item(1)
$feedSheet.Name = 'Feed_Ready_2026'

$headers = Get-HeaderMap
for ($c = 0; $c -lt $headers.Count; $c++) {
    $feedSheet.Cells.Item(1, $c + 1) = $headers[$c]
}
$feedSheet.Rows.Item(1).Font.Bold = $true
$feedSheet.Range('A1:V1').Interior.Color = 0xD9EAF7

$changedCounts = @{}
foreach ($header in $headers) { $changedCounts[$header] = 0 }

for ($r = 2; $r -le $sourceSheet.UsedRange.Rows.Count; $r++) {
    $title = Normalize-Text $sourceSheet.Cells.Item($r, 1).Value2
    if ([string]::IsNullOrWhiteSpace($title)) { continue }

    $values = @()
    for ($c = 1; $c -le 22; $c++) {
        $values += Normalize-Text $sourceSheet.Cells.Item($r, $c).Value2
    }

    $updated = @($values)
    $updated[3] = Normalize-Type $title $values[1] $values[3]
    $updated[2] = if ($updated[2] -match '^\s*$') { $values[2] } else { $updated[2] }

    for ($c = 1; $c -le 22; $c++) {
        $orig = $values[$c - 1]
        $new = $updated[$c - 1]
        if ($orig -ne $new) {
            $changedCounts[$headers[$c - 1]] += 1
        }
        $feedSheet.Cells.Item($r, $c) = $new
    }
}

# Add summary sheet.
$summarySheet = $targetBook.Worksheets.Add()
$summarySheet.Name = 'Summary_2026'
$summarySheet.Cells.Item(1, 1) = 'Column'
$summarySheet.Cells.Item(1, 2) = 'Entries changed'
$summarySheet.Rows.Item(1).Font.Bold = $true
$summarySheet.Range('A1:B1').Interior.Color = 0xD9EAF7

$summaryIndex = 2
foreach ($header in $headers) {
    $summarySheet.Cells.Item($summaryIndex, 1) = $header
    $summarySheet.Cells.Item($summaryIndex, 2) = $changedCounts[$header]
    $summaryIndex += 1
}
$summarySheet.Columns.Item(1).AutoFit(); $summarySheet.Columns.Item(2).AutoFit()

for ($col = 1; $col -le 22; $col++) {
    $feedSheet.Columns.Item($col).AutoFit()
}

$targetBook.SaveAs($outputPath)
Write-Host 'Saved feed-ready workbook to: ' + $outputPath
Write-Host 'Type changes:' + $changedCounts['Type']
Write-Host 'Summary counts:'
foreach ($header in $headers) {
    if ($changedCounts[$header] -gt 0) {
        Write-Host ($header + ': ' + $changedCounts[$header])
    }
}

$targetBook.Close($true)
$sourceBook.Close($false)
$excel.Quit()
