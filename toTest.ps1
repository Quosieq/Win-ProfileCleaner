#to test portions of code 

function ArchiveProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Full","Partial")]
        [string]$ArchiveMode,
        [Parameter(Mandatory=$false)]
        [string[]]$FoldersToArchive,
        [Parameter(Mandatory=$false)]
        [string]$OutputPath
    )

    # To archive profiles we need 7zip installed 
    $7zReg = "Registry::HKLM\SOFTWARE\7-Zip"

    if(-not (Test-Path -Path $7zReg)) {
        Write-Host "7zip not installed, you need it to archive profiles"
        $quickInstall = Read-Host("Do you want to install it now? (Y/N)")
        if($quickInstall -eq "Y") {
            $7zip = "https://7-zip.org/a/7z2500-x64.exe"
            $dlDir = "$PSScriptRoot\7zip.exe"

            Invoke-WebRequest -Uri $7zip -OutFile $dlDir
            Start-Process -FilePath "7zip.exe" -ArgumentList "/S" -Wait -NoNewWindow
            Remove-Item $dlDir
        }else {
            Write-Host "Please download and install 7zip to continue `nPress any key to exit.."
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
    }
    
    $7zPath = Get-ItemProperty -Path $7zReg
    $7zPath = $7zPath.Path
    $7zPath = Join-Path $7zPath "7z.exe"

    
    # Define Full Archive folder list
    $fullList = @(
        "Desktop",
        "Documents",
        "Downloads",
        "Pictures",
        "Videos"
    )
    # Empty array to collect directories from full mode or specified by the user for Partial mode 
    $folders = @()
    if($ArchiveMode -eq "Full"){
        Write-Host "Full archive mode: Include all predefined folers" -ForegroundColor Yellow
        $folders = $fullList
    }elseif($ArchiveMode -eq "Partial"){
        Write-Host "Partial archive mode: Include only specified folders" -ForegroundColor Yellow
        $folders = $FoldersToArchive
    }

    # Validate if folders to archive are correct 
    foreach($folder in $folders){
        $foldersPath = Join-Path $profileDir $folder
        if(-not (Test-Path -Path $foldersPath)) {
            Write-Warning "Folder $folder does not exists or there is misspelling, please check your spelling and try again.. "
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
    }

    # Now the archiving part 

    $username = $profileDir.Substring(9)
    $username = $username.Replace("\","")
    $archiveName = Join-Path $OutputPath "$($username)_archive_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    Write-Host "Archiving folders to $archivename"

}
try {
    ArchiveProfile -ArchiveMode Full -ErrorAction stop
}catch{
    Write-Error "Error archiving: $_"
}
