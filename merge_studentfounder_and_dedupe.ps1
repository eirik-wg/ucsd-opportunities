$workbookPath = 'C:\Users\eirikat\UCSD GEIR\20260929_Funding opportunities_reviewed.xlsx'
$headers = @(
    'Program Title','Program Description','Funding Amount/Prize Amount','Type','Visit Website','Open Application','Deadline','Catered Toward','Recurring','Characteristics','General Notes','Additional documents','Website link','UCSD Run','2025 Review Notes','Status','2026 Review Notes','Next Review Date','Review Log','Next Deadline','Estimated Deadline Date','Deadline Date Rationale'
)

$added = @(
    [pscustomobject]@{ Title='E-Team Program — Pioneer / Propel'; Description='Student-led teams building science- or engineering-based innovations can apply for non-dilutive grant funding and commercialization support.'; Amount='$5K Pioneer / $20K Propel (up to $25K total)'; Type='Accelerator'; Visit='VentureWell'; Open='Student-led team of at least 2 active, enrolled students at a U.S.-based college or university.'; Deadline='Sep 29, 2026'; Catered='Engineering / Technology'; Recurring='annual'; Characteristics='non-dilutive, student startup, engineering, science-based startup'; General='Added from Student Founder HQ database and checked against the official page.'; Additional='N/A'; URL='https://venturewell.org/e-team-program/'; Status='Open'; ReviewNotes='Added from Student Founder HQ; official page confirmed as live.'; ReviewLog='Reviewed from Student Founder HQ. Official landing page checked and retained.'; NextDeadline='Sep 29, 2026'; EstDate='2026-09-29'; Rationale='Official VentureWell page lists Sep 29, 2026 as the next deadline for the E-Team Program.' },
    [pscustomobject]@{ Title='New Venture Competition'; Description='Baylor’s annual startup competition gives student ventures a chance to win cash prizes and support resources.'; Amount='$200K+ in cash prizes/resources; $50K 1st, $25K 2nd, $10K 3rd'; Type='Competition'; Visit='Baylor University'; Open='Open to collegiate teams from accredited nonprofit universities worldwide.'; Deadline='Oct 1, 2026'; Catered='All industries'; Recurring='annual'; Characteristics='student venture, global, pitch competition'; General='Added from Student Founder HQ; official page checked for accuracy.'; Additional='N/A'; URL='https://hankamer.baylor.edu/baugh-center/new-venture'; Status='Open'; ReviewNotes='Added from Student Founder HQ database; official page cross-checked.'; ReviewLog='Reviewed from Student Founder HQ; official competition page retained as the canonical link.'; NextDeadline='Oct 1, 2026'; EstDate='2026-10-01'; Rationale='Official Baylor competition listing states Oct 1, 2026 as the next application deadline.' },
    [pscustomobject]@{ Title='America’s Startup'; Description='A national undergraduate startup competition that rewards early-stage founders with cash prizes and visibility.'; Amount='$25K for each finalist; up to $50K for grand-prize winners'; Type='Competition'; Visit='America250'; Open='Open to current undergraduate students at accredited U.S. colleges and trade schools.'; Deadline='Oct 8, 2026'; Catered='All industries'; Recurring='annual'; Characteristics='undergraduate, national, startup competition'; General='Added from Student Founder HQ database.'; Additional='N/A'; URL='https://america250.org/americas-startup/'; Status='Open'; ReviewNotes='URL retained from Student Founder HQ and checked against the official America250 page.'; ReviewLog='Reviewed from Student Founder HQ; official America250 page retained as the canonical link.'; NextDeadline='Oct 8, 2026'; EstDate='2026-10-08'; Rationale='Official America250 page lists Oct 8, 2026 as the next application deadline.' },
    [pscustomobject]@{ Title='iLaunch Competition'; Description='A startup pitch competition that awards cash prizes to promising early-stage ventures.'; Amount='$17.5K total ($10K 1st, $5K 2nd, $2.5K 3rd)'; Type='Competition'; Visit='Texas Tech Innovation Hub'; Open='Open to adults 18+; Texas Tech affiliation is not required.'; Deadline='Oct 15, 2026'; Catered='All industries'; Recurring='annual'; Characteristics='pitch competition, broad participation, cash prizes'; General='Added from Student Founder HQ; official page checked.'; Additional='N/A'; URL='https://www.depts.ttu.edu/research/research-park/Startup_Program_and_Events/Ideation/iLaunch/index.php'; Status='Open'; ReviewNotes='Added from Student Founder HQ with official Texas Tech URL.'; ReviewLog='Reviewed from Student Founder HQ and retained using the official TTU landing page.'; NextDeadline='Oct 15, 2026'; EstDate='2026-10-15'; Rationale='Official iLaunch page lists Oct 15, 2026 as the next deadline.' },
    [pscustomobject]@{ Title='CEO Global Pitch Competition'; Description='An annual pitch competition for student entrepreneurs where active CEO members compete for cash awards.'; Amount='$20K total ($8K 1st, $6K 2nd, $4K 3rd, $2K 4th)'; Type='Competition'; Visit='Collegiate Entrepreneurs’ Organization'; Open='Must be an active CEO member and currently enrolled undergraduate or graduate student.'; Deadline='Oct 18, 2026'; Catered='All industries'; Recurring='annual'; Characteristics='student pitch, national, active member requirement'; General='Added from Student Founder HQ list and matched to the official CEO event page.'; Additional='N/A'; URL='https://www.joinceo.org/events/globalconference#pitchcompetition'; Status='Open'; ReviewNotes='Official CEO event page confirmed.'; ReviewLog='Reviewed from Student Founder HQ and retained against the official CEO event page.'; NextDeadline='Oct 18, 2026'; EstDate='2026-10-18'; Rationale='Official CEO event page lists Oct 18, 2026 as the upcoming pitch competition deadline.' },
    [pscustomobject]@{ Title='TigerLaunch'; Description='Princeton’s student startup pitch event offers a significant non-dilutive prize pool for early-stage founders.'; Amount='$60K equity-free prize pool ($30K / $20K / $10K)'; Type='Competition'; Visit='Princeton Entrepreneurship Club'; Open='Current undergraduate or graduate student founder.'; Deadline='Oct 25, 2026'; Catered='All industries'; Recurring='annual'; Characteristics='student founder, pitch competition, equity-free'; General='Added from Student Founder HQ; official site validated.'; Additional='N/A'; URL='https://tigerlaunch.com/'; Status='Open'; ReviewNotes='Official TigerLaunch site checked and retained.'; ReviewLog='Reviewed from Student Founder HQ. Official TigerLaunch page is live and retained.'; NextDeadline='Oct 25, 2026'; EstDate='2026-10-25'; Rationale='Official TigerLaunch page lists Oct 25, 2026 as the next deadline.' },
    [pscustomobject]@{ Title='Y Combinator — Winter 2027'; Description='A global startup accelerator that accepts companies across industries, with a standard YC investment structure.'; Amount='$500K standard YC investment'; Type='Investment'; Visit='Y Combinator'; Open='Open globally to startups in essentially any industry.'; Deadline='Nov 2, 2026'; Catered='All industries'; Recurring='annual'; Characteristics='equity, accelerator, global, early-stage'; General='Added from Student Founder HQ list; included because it is listed in the site database even though it is not non-dilutive.'; Additional='N/A'; URL='https://www.ycombinator.com/apply'; Status='Open'; ReviewNotes='Included for completeness from Student Founder HQ; equity terms are noted in the listing.'; ReviewLog='Included from Student Founder HQ database and linked to the official YC application page.'; NextDeadline='Nov 2, 2026'; EstDate='2026-11-02'; Rationale='The official Y Combinator apply page states the next application deadline is Nov 2, 2026.' },
    [pscustomobject]@{ Title='Xcelerate Startup Competition'; Description='A healthtech pitch competition that awards equity-free cash prizes to startup teams with healthcare-focused innovation.'; Amount='$30K total equity-free cash prizes ($15K / $10K / $5K)'; Type='Competition'; Visit='World Health Expo Tech'; Open='Healthcare or health-adjacent startup with a working product or solution.'; Deadline='Nov 4, 2026'; Catered='Healthcare / Life Sciences'; Recurring='annual'; Characteristics='healthtech, startup competition, cash prizes'; General='Added from Student Founder HQ database; official URL checked.'; Additional='N/A'; URL='https://www.worldhealthexpo.com/events/healthcare/tech/whats-on/features/xcelerate-your-startup-pitch-competition/'; Status='Open'; ReviewNotes='Official WHX Tech competition page confirmed and retained.'; ReviewLog='Reviewed from Student Founder HQ and retained via the official WHX Tech competition page.'; NextDeadline='Nov 4, 2026'; EstDate='2026-11-04'; Rationale='Official page lists Nov 4, 2026 as the upcoming deadline for Xcelerate.' },
    [pscustomobject]@{ Title='Duquesne New Venture Challenge (DNVC)'; Description='A startup and business plan challenge that awards cash prizes and venture-stage support to early-stage ventures.'; Amount='$125,000+ total cash and prizes'; Type='Competition'; Visit='Duquesne University'; Open='Open to applicants across the continental U.S.; no Duquesne affiliation required for early stages.'; Deadline='Nov 15, 2026'; Catered='All industries'; Recurring='annual'; Characteristics='startup competition, early-stage, cash prizes'; General='Added from Student Founder HQ database and checked against the official Duquesne competition page.'; Additional='N/A'; URL='https://www.duq.edu/academics/colleges-and-schools/business/events-and-competitions/new-venture-challenge.php'; Status='Open'; ReviewNotes='Official Duquesne page confirmed.'; ReviewLog='Retained using the official Duquesne New Venture Challenge page.'; NextDeadline='Nov 15, 2026'; EstDate='2026-11-15'; Rationale='Official Duquesne page lists Nov 15, 2026 as the next application deadline.' },
    [pscustomobject]@{ Title='Entrepreneurship World Cup'; Description='A global startup competition that advances founders with equity-free cash prizes and a global pitch stage.'; Amount='$1M total equity-free cash prizes'; Type='Competition'; Visit='Global Entrepreneurship Network'; Open='Open globally to founders age 18+ and eligible legal entities.'; Deadline='May 31, 2027'; Catered='All industries'; Recurring='annual'; Characteristics='global, startup competition, equity-free'; General='Added from Student Founder HQ database.'; Additional='N/A'; URL='https://entrepreneurshipworldcup.com/'; Status='Open'; ReviewNotes='Official Entrepreneurship World Cup page confirmed and retained.'; ReviewLog='Reviewed from Student Founder HQ; official landing page retained as the canonical URL.'; NextDeadline='May 31, 2027'; EstDate='2027-05-31'; Rationale='Official Entrepreneurship World Cup landing page lists May 31, 2027 as the next competition round deadline.' },
    [pscustomobject]@{ Title='Dorm Room Fund — Apply for Funding'; Description='A student-focused venture fund that invests in early-stage startups with one or more student founding team members.'; Amount='$90K–$250K investment'; Type='Investment'; Visit='Dorm Room Fund'; Open='At least one founding team member should be currently enrolled or recently graduated.'; Deadline='Rolling (TBD)'; Catered='Engineering / Technology'; Recurring='rolling'; Characteristics='student venture fund, early-stage, equity'; General='Added from Student Founder HQ list; included to reflect the current list even though it is not non-dilutive.'; Additional='N/A'; URL='https://www.dormroomfund.com/'; Status='Open'; ReviewNotes='Included from Student Founder HQ; official Dorm Room Fund site confirmed.'; ReviewLog='Reviewed from Student Founder HQ; official Dorm Room Fund site retained as the canonical link.'; NextDeadline='Rolling (TBD)'; EstDate='2026-11-28'; Rationale='Dorm Room Fund is rolling and does not list a fixed close date, so the next general application window was used as a working date for filtering.' },
    [pscustomobject]@{ Title='GSEA — Global Student Entrepreneur Awards'; Description='A global student entrepreneur competition awarding cash prizes and recognition to promising student founders.'; Amount='$100K global cash prize pool; $50K / $25K / $15K top 3'; Type='Competition'; Visit='Entrepreneurs’ Organization'; Open='Undergraduate or graduate student founder with a controlling role in the business.'; Deadline='Varies (TBD)'; Catered='All industries'; Recurring='varies'; Characteristics='student entrepreneur, global, prize competition'; General='Added from Student Founder HQ database.'; Additional='N/A'; URL='https://eonetwork.org/gsea/apply/'; Status='Open'; ReviewNotes='Official EO GSEA page checked and retained.'; ReviewLog='Included from Student Founder HQ and linked to the official GSEA apply page.'; NextDeadline='Varies (TBD)'; EstDate='2026-11-28'; Rationale='The page reflects a variable cycle, so the next general application window was used for date filtering.' },
    [pscustomobject]@{ Title='Startup Runway'; Description='A startup showcase and pitch platform that connects early-stage founders with non-dilutive grant opportunities and network support.'; Amount='Prize amount varies by showcase; recent programs have offered $10K non-dilutive grants'; Type='Competition'; Visit='Startup Runway'; Open='Early-stage startup with a scalable business model.'; Deadline='Rolling (TBD)'; Catered='All industries'; Recurring='rolling'; Characteristics='early-stage startup, pitch showcase, non-dilutive opportunities'; General='Added from Student Founder HQ database and checked against the official Startup Runway page.'; Additional='N/A'; URL='https://startuprunway.org/apply-for-startup-runway-today/'; Status='Open'; ReviewNotes='Official Startup Runway page confirmed.'; ReviewLog='Reviewed from Student Founder HQ and retained using the official Startup Runway application page.'; NextDeadline='Rolling (TBD)'; EstDate='2026-11-28'; Rationale='Startup Runway is rolling, so a realistic short-term working date was used to keep the dataset filterable.' }
)

function NormalizedKey($value) {
    if ($null -eq $value) { return '' }
    $clean = [string]$value
    return ($clean.Trim() -replace '\s+', ' ').ToLowerInvariant()
}

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open($workbookPath)
$sheet = $workbook.Worksheets.Item('Reviewed_2026')

$seen = @{}
$finalRows = @()

for ($r = 2; $r -le $sheet.UsedRange.Rows.Count; $r++) {
    $title = [string]$sheet.Cells.Item($r, 1).Value2
    if ([string]::IsNullOrWhiteSpace($title)) { continue }
    $key = NormalizedKey $title
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true

    $finalRows += [pscustomobject]@{
        Title = $title.Trim()
        ProgramDescription = [string]$sheet.Cells.Item($r, 2).Value2
        Funding = [string]$sheet.Cells.Item($r, 3).Value2
        Type = [string]$sheet.Cells.Item($r, 4).Value2
        Visit = [string]$sheet.Cells.Item($r, 5).Value2
        OpenApp = [string]$sheet.Cells.Item($r, 6).Value2
        Deadline = [string]$sheet.Cells.Item($r, 7).Value2
        Catered = [string]$sheet.Cells.Item($r, 8).Value2
        Recurring = [string]$sheet.Cells.Item($r, 9).Value2
        Characteristics = [string]$sheet.Cells.Item($r, 10).Value2
        GeneralNotes = [string]$sheet.Cells.Item($r, 11).Value2
        Additional = [string]$sheet.Cells.Item($r, 12).Value2
        Website = [string]$sheet.Cells.Item($r, 13).Value2
        UCSDRun = [string]$sheet.Cells.Item($r, 14).Value2
        Review2025 = [string]$sheet.Cells.Item($r, 15).Value2
        Status = [string]$sheet.Cells.Item($r, 16).Value2
        Review2026 = [string]$sheet.Cells.Item($r, 17).Value2
        NextReview = [string]$sheet.Cells.Item($r, 18).Value2
        ReviewLog = [string]$sheet.Cells.Item($r, 19).Value2
        NextDeadline = [string]$sheet.Cells.Item($r, 20).Value2
        EstDate = [string]$sheet.Cells.Item($r, 21).Value2
        Rationale = [string]$sheet.Cells.Item($r, 22).Value2
    }
}

foreach ($entry in $added) {
    $key = NormalizedKey $entry.Title
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $finalRows += [pscustomobject]@{
            Title = $entry.Title
            ProgramDescription = $entry.Description
            Funding = $entry.Amount
            Type = $entry.Type
            Visit = $entry.Visit
            OpenApp = $entry.Open
            Deadline = $entry.Deadline
            Catered = $entry.Catered
            Recurring = $entry.Recurring
            Characteristics = $entry.Characteristics
            GeneralNotes = $entry.General
            Additional = $entry.Additional
            Website = $entry.URL
            UCSDRun = ''
            Review2025 = ''
            Status = $entry.Status
            Review2026 = $entry.ReviewNotes
            NextReview = ''
            ReviewLog = $entry.ReviewLog
            NextDeadline = $entry.NextDeadline
            EstDate = $entry.EstDate
            Rationale = $entry.Rationale
        }
    }
}

$sheet.Cells.Clear()
for ($i = 0; $i -lt $headers.Count; $i++) {
    $sheet.Cells.Item(1, $i + 1) = $headers[$i]
}

for ($idx = 0; $idx -lt $finalRows.Count; $idx++) {
    $r = $idx + 2
    $row = $finalRows[$idx]

    $sheet.Cells.Item($r, 1) = $row.Title
    $sheet.Cells.Item($r, 2) = $row.ProgramDescription
    $sheet.Cells.Item($r, 3) = $row.Funding
    $sheet.Cells.Item($r, 4) = $row.Type
    $sheet.Cells.Item($r, 5) = $row.Visit
    $sheet.Cells.Item($r, 6) = $row.OpenApp
    $sheet.Cells.Item($r, 7) = $row.Deadline
    $sheet.Cells.Item($r, 8) = $row.Catered
    $sheet.Cells.Item($r, 9) = $row.Recurring
    $sheet.Cells.Item($r, 10) = $row.Characteristics
    $sheet.Cells.Item($r, 11) = $row.GeneralNotes
    $sheet.Cells.Item($r, 12) = $row.Additional
    $sheet.Cells.Item($r, 13) = $row.Website
    $sheet.Cells.Item($r, 14) = $row.UCSDRun
    $sheet.Cells.Item($r, 15) = $row.Review2025
    $sheet.Cells.Item($r, 16) = $row.Status
    $sheet.Cells.Item($r, 17) = $row.Review2026
    $sheet.Cells.Item($r, 18) = $row.NextReview
    $sheet.Cells.Item($r, 19) = $row.ReviewLog
    $sheet.Cells.Item($r, 20) = $row.NextDeadline

    if (-not [string]::IsNullOrWhiteSpace($row.EstDate)) {
        try {
            $dt = [datetime]::Parse($row.EstDate)
            $sheet.Cells.Item($r, 21).Value2 = $dt.ToOADate()
            $sheet.Cells.Item($r, 21).NumberFormat = 'yyyy-mm-dd'
        } catch {
            $sheet.Cells.Item($r, 21) = $row.EstDate
        }
    }

    $sheet.Cells.Item($r, 22) = $row.Rationale
}

$sheet.Rows.Item(1).Font.Bold = $true
for ($c = 1; $c -le 22; $c++) {
    $sheet.Columns.Item($c).AutoFit()
}

$workbook.Save()
Write-Host ('Final rows after dedupe and merge: ' + $finalRows.Count)

foreach ($entry in $added) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri $entry.URL -Method Head -TimeoutSec 20
        Write-Host ('URL OK: ' + $entry.URL + ' => ' + $r.StatusCode)
    } catch {
        try {
            $r = Invoke-WebRequest -UseBasicParsing -Uri $entry.URL -TimeoutSec 20
            Write-Host ('URL OK (GET fallback): ' + $entry.URL + ' => ' + $r.StatusCode)
        } catch {
            Write-Host ('URL ERR: ' + $entry.URL + ' => ' + $_.Exception.Message)
        }
    }
}

$workbook.Close($true)
$excel.Quit()
