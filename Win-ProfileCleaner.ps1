<#
.SYNOPSIS
Remove user profiles older user profiles.

.DESCRIPTION
Scan C:\Users and chceck each profile NTUSER.DAT last modified date to check when user logged in
Filter out system accounds and local admin (specified before egzecution) and remove (with option to archive) profiles older than specified time 

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [int]$DaysInactive = 90,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Full","Partial")]
    [string]$ArchiveMode,
    [Parameter(Mandatory=$false)]
    [string[]]$FoldersToArchive,
    [Parameter(Mandatory=$false)]
    [string]$OutputPath 
)

function ArchiveProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Full","Partial")]
        [string]$ArchiveMode,
        [Parameter(Mandatory=$false)]
        [string[]]$FoldersToArchive,
        [Parameter(Mandatory=$true)]
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
    $7z = Join-Path $7zPath "7z.exe"

    
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
        $folders = @() # For some reason full bleeds into partial mode - clean array here to test this 
        Write-Host "Partial archive mode: Include only specified folders" -ForegroundColor Yellow
        $folders = $FoldersToArchive.clone()
    }

    
    # Validate if folders to archive are correct 
    $validFolders = @()
    foreach($folder in $folders){
        $foldersPath = Join-Path $profileDir $folder        
        if(-not (Test-Path -Path $foldersPath)) {
            Write-Warning "Folder $folder does not exists or there is misspelling, please check your spelling and try again.. "
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit
        }
        $validFolders += $foldersPath
    }

    Write-Host $validFolders
    
    $username = $profileDir.Substring(9)
    $username = $username.Replace("\","")
    $archiveName = Join-Path $OutputPath "$($username)_archive_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    Write-Host "Archiving folders to $archivename" -ForegroundColor Yellow

    
    try{
        
        $arguments = "a -tzip `"$archiveName`""
        foreach($folderPath in $validFolders){
            $arguments += " `"$folderpath\*`""
        }
        
        $archivingProcess = Start-Process -FilePath $7z -ArgumentList $arguments -Wait -NoNewWindow -PassThru
        if($archivingProcess.ExitCode -eq 0) {
            Write-Host "Profile archived to $($OutputPath)\$($archiveName)" -ForegroundColor Gray
            return 0
        }else{
            Write-Host "Something went wrong`nFailed to archive folders - 7zip error code $($archivingProcess.ExitCode) `nCheck code, restart script and try again" -ForegroundColor Red
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return 1
        }
    }catch{
        Write-Host "Error: $_"
    }

}

$profiles = Get-ChildItem -Path "C:\users" -Depth 1 -Include *.dat
$excludedProfiles = @("Public", "Default", "Admin", $env:USERNAME) # To not remove essential proflies (change whatever you need)
$today = Get-Date

#big boi
foreach ($user in $profiles) {
    $profileDir = Split-Path -Path $user.FullName -Parent
    
    if($profileDir.Split('\')[-1] -notin $excludedProfiles) {
        Write-Host "`nProfile Path: $profileDir"
        $loginDiff = New-TimeSpan -Start $user.LastWriteTime -End $today
        $username = $profileDir.Substring(9).Replace("\","")
    
        if($loginDiff -gt $DaysInactive) {
            Write-Host "User $username hasn't logged in more than $DaysInactive days - last login $($loginDiff.Days) days ago" -ForegroundColor Yellow
            
            # Ask about archiving
            $archiveConfirm = Read-Host "Would you like to archive this profile? (Y/N)"
            $removeProfile = $false

            if($archiveConfirm -eq "y") {
                # Archive path
                Write-Host "`n===== Archive modes =====" -ForegroundColor Magenta
                Write-Host "1. Full: predefined folders `n2. Partial: Define folders to archive`n"
                [int]$archiveChoice = Read-Host "Which mode to archive use for this profile? (1/2)"
                $outputPath = Read-Host "`nPlease specify path where archive will be stored"

                while($true) {
                    if($archiveChoice -eq 1) {
                        $return = ArchiveProfile -ArchiveMode Full -OutputPath $outputPath
                        $removeProfile = ($return -eq 0)
                        break
                    }
                    elseif($archiveChoice -eq 2) {
                        $foldersToArchive = (Read-Host "`nUsage example: Desktop, Documents `nPlease specify folders to archive") -split ',' | ForEach-Object { $_.Trim() }
                        $return = ArchiveProfile -ArchiveMode Partial -FoldersToArchive $foldersToArchive -OutputPath $outputPath
                        $removeProfile = ($return -eq 0)
                        break
                    }
                    else {
                        Write-Host "Wrong input, please try again.. "
                        continue
                    }
                }
            }
            else {
                # Non-archive path
                $confirmRemove = Read-Host "Skip archiving. Remove profile anyway? (Y/N)"
                if($confirmRemove -eq "y") {
                    $removeProfile = $true
                }
                else {
                    Write-Host "Skipping profile removal for $username" -ForegroundColor Yellow
                    continue  # Move to next profile
                }
            }

            # Profile removal logic
            if($removeProfile) {
                try {
                    Write-Host "Removing user profile for $username..."
                    $profileToRemove = Get-CimInstance Win32_UserProfile | Where-Object {$_.LocalPath -eq $profileDir} | Remove-CimInstance
                    Write-Host "Profile removed successfully" -ForegroundColor Green
                }
                catch {
                    Write-Host "Failed to remove profile: $_" -ForegroundColor Red
                }
            }
        }
    }
}