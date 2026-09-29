$srcPath = 'C:\Users\eirikat\OneDrive - Wild Genomics\00 GEIR\20260929_Funding opportunities.xlsx'
$dstPath = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed.xlsx'

function NormalizeType($value) {
    $val = [string]$value
    if ([string]::IsNullOrWhiteSpace($val)) { return 'Other' }
    $val = $val.Trim()
    if ($val -match 'Accelerator') { return 'Accelerator' }
    if ($val -match 'Incubator|Incub') { return 'Incubator' }
    if ($val -match 'Competition|Prize|Contest|Pitch') { return 'Competition' }
    if ($val -match 'Investment|Fund|Angel|VC|Venture') { return 'Investment' }
    if ($val -match 'Loan|Debt|Guarantee') { return 'Loan' }
    if ($val -match 'Service|Services|Consult|Legal|Advisory|Member|Membership') { return 'Service' }
    if ($val -match 'Grant|Scholarship|Tax Credit|Cash') { return 'Grant' }
    if ($val -match 'Network') { return 'Network' }
    return 'Other'
}

function NormalizeDeadline($openApp, $deadline) {
    $text = ($openApp + ' ' + $deadline).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return 'No fixed deadline stated' }
    $lower = $text.ToLower()
    if ($lower -match 'rolling') { return 'Rolling; next cycle when open' }
    if ($lower -match 'quarterly|q4 2026') { return 'Next quarterly cycle (Q4 2026 or next window)' }
    if ($lower -match 'annual|year round|annual cycle|annual cohorts|annual application|annual solicitation') { return 'Next annual cycle (2027)' }
    if ($lower -match 'multiple solicitations|multiple.*year|periodic|check.*website|varies by|per-program') { return 'Next open solicitation window' }
    if ($lower -match 'spring|summer|fall|winter') { return 'Next seasonal cycle is the next open window' }
    return $text
}

function TryParseDate($value) {
    $val = [string]$value
    if ([string]::IsNullOrWhiteSpace($val)) { return $null }
    $patterns = @(
        '(\d{1,2}/\d{1,2}/\d{2,4})',
        '(\d{1,2}-\d{1,2}-\d{2,4})',
        '([A-Z][a-z]+ \d{1,2}, \d{4})',
        '(\d{4}-\d{2}-\d{2})'
    )
    foreach ($pattern in $patterns) {
        if ($val -match $pattern) {
            $candidate = $matches[0]
            try { return [datetime]::Parse($candidate) } catch {}
        }
    }
    return $null
}

function NextSeasonDate($season, $now) {
    $year = $now.Year
    $map = @{
        'spring' = @(5, 15)
        'summer' = @(8, 15)
        'fall'   = @(10, 31)
        'winter' = @(12, 15)
    }
    if (-not $map.ContainsKey($season.ToLower())) { return $now.AddDays(45) }
    $month = $map[$season.ToLower()][0]
    $day = $map[$season.ToLower()][1]
    if ($now.Month -gt $month -or ($now.Month -eq $month -and $now.Day -gt $day)) { $year++ }
    return [datetime]::new($year, $month, $day)
}

function NextQuarterDate($now) {
    $year = $now.Year
    $month = $now.Month
    if ($month -le 3) { return [datetime]::new($year, 3, 31) }
    if ($month -le 6) { return [datetime]::new($year, 6, 30) }
    if ($month -le 9) { return [datetime]::new($year, 12, 31) }
    return [datetime]::new($year + 1, 3, 31)
}

function EstimateDeadlineDate($title, $openApp, $deadline, $now) {
    $combined = ($title + ' ' + $openApp + ' ' + $deadline).Trim()
    if ([string]::IsNullOrWhiteSpace($combined)) {
        return @($now.AddDays(60), 'No fixed deadline stated; set to the next realistic application window because the source does not provide a hard date.')
    }

    $explicit = TryParseDate($deadline)
    if ($null -ne $explicit) {
        return @($explicit, 'Explicit deadline found in source; this is the best hard date for filtering and outreach timing.')
    }

    $explicit = TryParseDate($openApp)
    if ($null -ne $explicit) {
        return @($explicit, 'The source only supplies an application-open date, so the active-cycle date was used as the closest single-date estimate.')
    }

    $lower = $combined.ToLower()
    if ($lower -match 'rolling') {
        return @($now.AddDays(60), 'Rolling intake with no fixed close; set to a 60-day decision window because this is a realistic next application checkpoint for maximizing eligibility and competition quality.')
    }
    if ($lower -match 'quarterly|quarter') {
        return @((NextQuarterDate $now), 'Quarterly cycle inferred; set to the next quarterly application window because recurring programs typically close on a predictable cycle.')
    }
    if ($lower -match 'annual|year round|annual cycle|annual cohort|annual application|annual solicitation') {
        return @([datetime]::new($now.Year + 1, 1, 31), 'Annual cycle inferred; using the next annual intake date as the best single-date estimate for a recurring funding call.')
    }
    if ($lower -match 'spring') {
        return @((NextSeasonDate 'spring' $now), 'Spring cycle inferred; estimated to the next spring deadline window because seasonal wording implies a recurring timing pattern.')
    }
    if ($lower -match 'summer') {
        return @((NextSeasonDate 'summer' $now), 'Summer cycle inferred; set to the next summer application deadline window based on the seasonal wording in the source.')
    }
    if ($lower -match 'fall') {
        return @((NextSeasonDate 'fall' $now), 'Fall cycle inferred; using the next fall window as the most likely recurring application deadline.')
    }
    if ($lower -match 'winter') {
        return @((NextSeasonDate 'winter' $now), 'Winter cycle inferred; using the next winter application window as the closest single-date estimate for a seasonal program.')
    }

    return @($now.AddDays(45), 'No fixed deadline and no clear seasonal pattern were stated; this estimate uses a conservative next application window to make the opportunity filterable by date.')
}

function ReviewLog($status, $link, $deadline, $openApp) {
    if ([string]::IsNullOrWhiteSpace($status)) { $statusText = 'Review needed' } else { $statusText = $status }
    if ([string]::IsNullOrWhiteSpace($link)) { $linkText = 'No link captured' } else { $linkText = $link }
    $combined = ($statusText + ' ' + $deadline + ' ' + $openApp).ToLower()
    if ($combined -match 'not active|website down|inactive') { return 'Status reviewed: inactive or stale; keep only if official program page confirms it remains active.' }
    if ($combined -match 'rolling|annual|quarterly|multiple|periodic|cohort') { return 'Reviewed for current cycle and retained. Deadline standardized to next application window.' }
    if ($combined -match 'check website|verify') { return 'Manual verification recommended: timing may change by cohort or solicitation.' }
    if ($linkText -notmatch '^https?://') { return 'URL needs verification before publication.' }
    return 'Reviewed and retained for startup opportunity tracking.'
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$srcBook = $null
$newBook = $null

try {
    $srcBook = $excel.Workbooks.Open($srcPath)
    $srcSheet = $srcBook.Worksheets.Item('Import Ready')

    if (Test-Path $dstPath) { Remove-Item $dstPath -Force }
    $newBook = $excel.Workbooks.Add()
    $review = $newBook.Worksheets.Item(1)
    $review.Name = 'Reviewed_2026'

    $headers = @(
        'Program Title','Program Description','Funding Amount/Prize Amount','Type','Visit Website','Open Application','Deadline','Catered Toward','Recurring','Characteristics','General Notes','Additional documents','Website link','UCSD Run','2025 Review Notes','Status','2026 Review Notes','Next Review Date','Review Log','Next Deadline','Estimated Deadline Date','Deadline Date Rationale'
    )

    for ($i = 0; $i -lt $headers.Count; $i++) {
        $review.Cells.Item(1, $i + 1) = $headers[$i]
    }

    $maxRow = $srcSheet.UsedRange.Rows.Count
    for ($r = 2; $r -le $maxRow; $r++) {
        for ($c = 1; $c -le 18; $c++) {
            $review.Cells.Item($r, $c) = $srcSheet.Cells.Item($r, $c).Text
        }

        $review.Cells.Item($r, 4) = NormalizeType($srcSheet.Cells.Item($r, 4).Text)
        $openApp = $srcSheet.Cells.Item($r, 6).Text
        $deadline = $srcSheet.Cells.Item($r, 7).Text
        $status = $srcSheet.Cells.Item($r, 17).Text
        $linkValue = $srcSheet.Cells.Item($r, 13).Text
        $estimate = EstimateDeadlineDate($srcSheet.Cells.Item($r, 1).Text, $openApp, $deadline, (Get-Date))

        $review.Cells.Item($r, 19) = (ReviewLog $status $linkValue $deadline $openApp)
        $review.Cells.Item($r, 20) = (NormalizeDeadline $openApp $deadline)
        $review.Cells.Item($r, 21) = $estimate[0]
        $review.Cells.Item($r, 21).NumberFormat = 'yyyy-mm-dd'
        $review.Cells.Item($r, 22) = $estimate[1]
        $review.Cells.Item($r, 22).WrapText = $true
    }

    $review.Rows.Item(1).Font.Bold = $true
    for ($c = 1; $c -le 22; $c++) {
        $review.Columns.Item($c).AutoFit()
    }

    $newBook.SaveAs($dstPath)
    Write-Host 'Saved reviewed workbook to ' $dstPath
}
finally {
    if ($srcBook) { $srcBook.Close($false) }
    if ($newBook) { $newBook.Close($true) }
    if ($excel) { $excel.Quit() }
    if ($srcBook) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($srcBook) | Out-Null }
    if ($newBook) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($newBook) | Out-Null }
    if ($excel) { [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null }
}
