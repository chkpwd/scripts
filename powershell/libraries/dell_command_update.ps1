$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0'

function Remove-PreviousDellInstallsAndServices {
    $UpdateServicePaths = @("$($env:ProgramData)\Dell\UpdateService","$($env:ProgramData)\Dell\drivers")
    foreach($UpdateServicePath in $UpdateServicePaths) {
        if (Test-Path $UpdateServicePath) {
            Remove-Item -Path $UpdateServicePath -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    $DCUPackageUinstallString = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName -like "Dell Command | Update*" }).UninstallString

    if ($DCUPackageUinstallString) {
        Write-Host "Uninstalling previous Dell Command | Update package..."
        Start-Process cmd.exe -ArgumentList "/c $DCUPackageUinstallString /qn /norestart /l*v c:\temp\dcu_uninstall.log" -NoNewWindow
    }
}

function Get-DCULatestURL {
    $Headers = @{
        "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/png,image/svg+xml,*/*;q=0.8"
        "Accept-Language" = "en-US,en;q=0.5"
        "Accept-Encoding" = "gzip, deflate, br, zstd"
    }
    $Page = Invoke-WebRequest `
            -UseBasicParsing `
            -UserAgent $UserAgent `
            -Headers $Headers `
            -Method Get `
            -Uri 'https://www.dell.com/support/kbdoc/en-us/000177325/dell-command-update'
    $URL = $Page.Links | 
                    Where-Object {$_.outerHTML -like "*Dell Command | Update Windows Universal Application*"} | 
                    Select-Object -ExpandProperty href -First 1
    $Output = (Invoke-WebRequest -Uri $URL -UseBasicParsing -Method Get -UserAgent $UserAgent -Headers $Headers).content.ToString()
    $MatchedItems = $Output | 
                Select-String -Pattern '(?<Uri>https://dl.dell.com/FOLDER[^/]+/./(?<FileName>Dell-Command-Update-Windows-Universal-Application_[^_]+_WIN_(?<Version>[\d\.]+)_.{3}\.EXE))(?:.*>(?<Packagehash>[a-f0-9]{64})<)' -AllMatches
    $Uri = $MatchedItems.Matches | 
                Select-Object -ExpandProperty Groups | 
                Where-Object { $_.Name -eq 'Uri' } | 
                Select-Object -ExpandProperty Value
    $Packagehash = $MatchedItems.Matches |
                Select-Object -ExpandProperty Groups |
                Where-Object { $_.Name -eq 'Packagehash' } |
                Select-Object -ExpandProperty Value
    return $Uri, $Packagehash
}

function Get-DCUInstallerFile {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $InstallerPath = 'C:\Temp\DellCommandUpdate'
    $results = Get-DCULatestURL

    if (-not (Test-Path "$InstallerPath\Dell-Command-Update.exe") -or (Get-FileHash -Path "$InstallerPath\Dell-Command-Update.exe" -Algorithm SHA256).Hash -ne $results[1]) {
        mkdir $InstallerPath -Force | Out-Null
        Invoke-WebRequest -Uri $results[0] -UseBasicParsing -OutFile "$InstallerPath\Dell-Command-Update.exe" -UserAgent $UserAgent
    }

    return Get-ChildItem "$InstallerPath\Dell-Command-Update.exe" -ErrorAction SilentlyContinue
}

$InstallDCU = {
    # Fix bad factory installs that would actually prevent new/updated DCU installs from working.
    Remove-PreviousDellInstallsAndServices

    # Get the latest DCU installer
    $InstallerFile = Get-DCUInstallerFile
    $Arguments = "/s"
    try {
        $InstallerLogFile = "C:\Temp\dcu_install-$((Get-Date -format 'MM-dd-yyy-hh:mm').ToString()).log"
        $Arguments += " /l=`"$InstallerLogFile`""
    } catch {
        Write-Warning "Failed to create log file: $_"
    }
    $Process = Start-Process -Wait $InstallerFile -ArgumentList $Arguments -PassThru -NoNewWindow -ErrorAction Ignore
    return $Process.ExitCode
}

$ExitCode = & $InstallDCU

if ($ExitCode -in 2,5,14) #https://www.dell.com/support/manuals/en-ae/dell-update-packages/dup_framework_23.12.00_ug_pub/exit-codes-for-cli?guid=guid-709bb23f-1f40-492f-8774-bbed273df825&lang=en-us
{
    return "PendingRebootRequired"
}