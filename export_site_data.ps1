$sourcePath = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed.xlsx'
$outputPath = 'C:\Users\eirikat\UCSD GEIR\data\opportunities.dat'
$airtableCsvPath = 'C:\Users\eirikat\UCSD GEIR\data\airtable_import.csv'
# Must match PAYLOAD_KEY in app.js and scripts/sync-airtable.mjs
$payloadKey = 'ucsd-founder-funding-2026'

# gzip -> XOR with key -> base64, prefixed with a format tag. Deters casual scraping of the raw data file;
# the browser reverses it in app.js (see unprotectPayload).
function Protect-Payload([string]$json, [string]$key) {
    $plain = [System.Text.Encoding]::UTF8.GetBytes($json)
    $ms = New-Object System.IO.MemoryStream
    $gz = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
    $gz.Write($plain, 0, $plain.Length)
    $gz.Close()
    $bytes = $ms.ToArray()
    $k = [System.Text.Encoding]::UTF8.GetBytes($key)
    for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = $bytes[$i] -bxor $k[$i % $k.Length] }
    return 'UCSDF1.' + [Convert]::ToBase64String($bytes)
}

function Normalize-Text($value) {
    if ($null -eq $value) { return '' }
    $s = [string]$value
    # Repair UTF-8-as-Latin-1 mojibake from imported sources: re-encode as Windows-1252 bytes, decode as UTF-8
    if ($s -match [string][char]0x00E2 -or $s -match [string][char]0x00C2) {
        try {
            $bytes = [System.Text.Encoding]::GetEncoding(1252).GetBytes($s)
            $fixed = [System.Text.Encoding]::UTF8.GetString($bytes)
            if ($fixed -notmatch [string][char]0xFFFD) { $s = $fixed }
        } catch {}
    }
    return $s.Trim()
}

function Get-Organizer($title, $ucsdRun) {
    if ($title -match 'UCSD|UC San Diego|Rady|Jacobs|Scripps|Calit2|Qualcomm Institute') { return 'UC San Diego' }
    if ($title -match 'San Diego|CONNECT|BioCom|Cleantech') { return 'San Diego ecosystem' }
    if ($title -match 'NSF|NIH|SBIR|STTR|DoD|Navy|NIWC|ARPA') { return 'Federal program' }
    if ($title -match 'California|CA ') { return 'State of California' }
    return 'External program'
}

function Get-FundingModel($type, $text) {
    $t = $text -replace 'equity[- ]free', '' -replace 'non[- ]dilutive', '' -replace 'no equity', ''
    if ($type -eq 'Investment' -or $t -match 'equity|dilutive|venture capital|angel invest') { return 'Dilutive / equity' }
    if ($type -eq 'Loan') { return 'Loan / debt' }
    if ($type -in @('Service','Network','Incubator') -and $text -notmatch 'grant|prize|\$') { return 'Non-cash support' }
    return 'Non-dilutive'
}

function Get-Geography($text) {
    if ($text -match 'ucsd|uc san diego') { return 'UCSD only' }
    if ($text -match 'san diego|southern california') { return 'San Diego region' }
    if ($text -match 'california|statewide') { return 'California' }
    if ($text -match 'global|worldwide|international') { return 'International / global' }
    return 'National / U.S.'
}

function Get-Industry($text) {
    if ($text -match 'biotech|medtech|health|life science|pharma|medical') { return 'Healthcare / life sciences' }
    if ($text -match 'climate|cleantech|energy|sustainab|ocean|blue tech') { return 'Climate / energy' }
    if ($text -match 'defense|national security|dual-use|dod|navy') { return 'Defense / dual-use' }
    if ($text -match 'social|community|equity|impact|nonprofit') { return 'Social impact' }
    if ($text -match 'engineering|hardware|robotics|device|deep tech|semiconductor') { return 'Engineering / technology' }
    if ($text -match 'ai|software|saas|digital|data') { return 'Software / AI' }
    return 'All industries'
}

function Get-Eligibility($openApp, $cateredToward, $generalNotes, $description) {
    $items = @()
    foreach ($src in @($openApp, $cateredToward, $generalNotes)) {
        $s = Normalize-Text $src
        if ($s -and $s.Length -gt 3) {
            foreach ($part in ($s -split '(?<=[.;])\s+|\s*\|\s*')) {
                $p = $part.Trim().TrimEnd('.', ';')
                if ($p.Length -gt 8 -and $p.Length -lt 220 -and -not ($items -contains $p)) { $items += $p }
            }
        }
    }
    if ($items.Count -eq 0) {
        $d = Normalize-Text $description
        $first = ($d -split '(?<=\.)\s+')[0]
        if ($first) { $items += $first.TrimEnd('.') }
    }
    return @($items | Select-Object -First 6)
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$wb = $excel.Workbooks.Open($sourcePath)
$ws = $wb.Worksheets.Item('Reviewed_2026')
$lastRow = $ws.UsedRange.Rows.Count

$rows = @()
$allRows = @()
for ($r = 2; $r -le $lastRow; $r++) {
    $title = Normalize-Text $ws.Cells.Item($r, 1).Value2
    if (-not $title) { continue }

    $description   = Normalize-Text $ws.Cells.Item($r, 2).Value2
    $amount        = Normalize-Text $ws.Cells.Item($r, 3).Value2
    $type          = Normalize-Text $ws.Cells.Item($r, 4).Value2
    $openApp       = Normalize-Text $ws.Cells.Item($r, 6).Value2
    $deadlineRaw   = $ws.Cells.Item($r, 7).Value2
    $deadlineText  = Normalize-Text $ws.Cells.Item($r, 7).Text
    $cateredToward = Normalize-Text $ws.Cells.Item($r, 8).Value2
    $recurring     = Normalize-Text $ws.Cells.Item($r, 9).Value2
    $generalNotes  = Normalize-Text $ws.Cells.Item($r, 11).Value2
    $link          = Normalize-Text $ws.Cells.Item($r, 13).Value2
    if (-not $link) { $link = Normalize-Text $ws.Cells.Item($r, 5).Value2 }
    $ucsdRun       = Normalize-Text $ws.Cells.Item($r, 14).Value2
    $status        = Normalize-Text $ws.Cells.Item($r, 16).Value2
    $nextDeadline  = Normalize-Text $ws.Cells.Item($r, 20).Value2
    $estRaw        = $ws.Cells.Item($r, 21).Value2
    $fit           = Normalize-Text $ws.Cells.Item($r, 23).Value2
    $bestFor       = Normalize-Text $ws.Cells.Item($r, 24).Value2
    $stage         = Normalize-Text $ws.Cells.Item($r, 25).Value2
    $eligLabel     = Normalize-Text $ws.Cells.Item($r, 26).Value2
    $tier          = Normalize-Text $ws.Cells.Item($r, 28).Value2

    if ($status -match 'inactive|not active|website down') { $isActive = $false } else { $isActive = $true }
    $isTopTier = ($tier -in @('Tier 1','Tier 2'))

    $estDate = $null
    if ($estRaw -is [double]) { $estDate = [datetime]::FromOADate($estRaw) }
    elseif ($estRaw) { try { $estDate = [datetime]::Parse([string]$estRaw) } catch {} }

    $hasHardDate = ($deadlineRaw -is [double]) -or ($deadlineText -match '\d{1,2}/\d{1,2}/\d{2,4}|\d{4}-\d{2}-\d{2}|[A-Z][a-z]+ \d{1,2},? \d{4}')
    $isRolling = ($nextDeadline -match 'rolling|year round|open annually|ongoing') -or ($recurring -match 'year round|rolling') -or ($deadlineText -match 'rolling|year round|open annually|ongoing')
    $deadlineKind = if ($hasHardDate) { 'confirmed' } elseif ($isRolling) { 'rolling' } else { 'expected' }

    $text = ($title + ' ' + $description + ' ' + $cateredToward + ' ' + $eligLabel + ' ' + $generalNotes).ToLowerInvariant()

    $summary = $description
    if ($summary.Length -gt 260) { $summary = $summary.Substring(0, 257).TrimEnd() + '...' }

    $tierRank = if ($tier -eq 'Tier 1') { 1 } elseif ($tier -eq 'Tier 2') { 2 } elseif ($tier -eq 'Tier 3') { 3 } else { 4 }

    $allRows += [pscustomobject]@{
        id            = 'opp-' + $r
        title         = $title
        organizer     = Get-Organizer $title $ucsdRun
        summary       = $summary
        description   = $description
        type          = $type
        fundingModel  = Get-FundingModel $type $text
        amount        = if ($amount) { $amount } else { 'Varies' }
        deadline      = if ($estDate) { $estDate.ToString('yyyy-MM-dd') } else { '' }
        deadlineKind  = $deadlineKind
        deadlineNote  = $nextDeadline
        recurring     = $recurring
        audience      = $eligLabel
        geography     = Get-Geography $text
        industry      = Get-Industry $text
        stage         = $stage
        bestFor       = $bestFor
        fit           = $fit
        tier          = $tier
        tierRank      = $tierRank
        ucsdRun       = ($ucsdRun -match '^(yes|y|true|x)$' -or $title -match 'UCSD|UC San Diego')
        eligibility   = [string[]]@(Get-Eligibility $openApp $cateredToward $generalNotes $description)
        url           = $link
        status        = if ($status) { $status } else { 'Active' }
        isActive      = $isActive
        isTopTier     = $isTopTier
    }
}

# Website payload: every active opportunity, all tiers. The site lets founders choose which tiers to show.
$rows = @($allRows | Where-Object { $_.isActive } | Select-Object -Property * -ExcludeProperty description, status, isActive, isTopTier)

$wb.Close($false)
$excel.Quit()

$selected = @($rows | Sort-Object -Property @{Expression='tierRank'}, @{Expression={ if ($_.deadline) { $_.deadline } else { '9999-12-31' } }})

$payload = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
    source      = 'Airtable-ready export from 20260929_Funding opportunities_reviewed.xlsx (Reviewed_2026)'
    count       = $selected.Count
    opportunities = $selected
}

New-Item -ItemType Directory -Force -Path (Split-Path $outputPath) | Out-Null
$json = $payload | ConvertTo-Json -Depth 6 -Compress
[System.IO.File]::WriteAllText($outputPath, (Protect-Payload $json $payloadKey), (New-Object System.Text.UTF8Encoding($false)))

# Airtable import file: every row, field names match scripts/sync-airtable.mjs
$csvRows = $allRows | ForEach-Object {
    [pscustomobject]@{
        'Program Title'               = $_.title
        'Organizer'                   = $_.organizer
        'Program Description'         = $_.description
        'Type'                        = $_.type
        'Funding Model'               = $_.fundingModel
        'Funding Amount/Prize Amount' = $_.amount
        'Estimated Deadline Date'     = $_.deadline
        'Deadline Kind'               = $_.deadlineKind
        'Next Deadline'               = $_.deadlineNote
        'Recurring'                   = $_.recurring
        'Eligibility Label'           = $_.audience
        'Geography'                   = $_.geography
        'Industry'                    = $_.industry
        'Founder Stage'               = $_.stage
        'Best For'                    = $_.bestFor
        'Student Startup Fit'         = $_.fit
        'Priority Tier'               = $_.tier
        'UCSD Run'                    = if ($_.ucsdRun) { 'checked' } else { '' }
        'Eligibility'                 = ($_.eligibility -join "`n")
        'Website link'                = $_.url
        'Status'                      = $_.status
        'Show on Website'             = if ($_.isActive) { 'checked' } else { '' }
    }
}
$csvText = ($csvRows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
[System.IO.File]::WriteAllText($airtableCsvPath, $csvText, (New-Object System.Text.UTF8Encoding($true)))

Write-Host ('All rows: ' + $allRows.Count + ' -> ' + $airtableCsvPath)

Write-Host ('Active (all tiers): ' + $rows.Count)
Write-Host ('Exported: ' + $selected.Count + ' -> ' + $outputPath)
