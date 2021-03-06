<#  
    Oppstallere is a PowerShell script
    derived from tmmjelde's script
    for automatically updating Valheim Dedicated Server,
    known as just Valheim from here on,
    on Windows.
#>

# Start server
Function Start-Valheim {
    $valheimProcess = Get-Process valheim_server -ErrorAction SilentlyContinue

    if ($valheimProcess) {
        Write-Host "A running Valheim instance was detected. Skipping start of Valheim."
    }
    else {
        $env:SteamAppId = "892970"

        Write-Host "A running Valheim instance was not detected. Starting Valheim..."

        Start-Process "$($config.forceinstalldir)\valheim_server.exe" -ArgumentList "-nographics -batchmode -name `"$($config.servername)`" -port $($config.port) -world $($config.world) -password $($config.password)"
    }
}

# Update server
Function Update-Valheim {
    $valheimProcess = Get-Process valheim_server -ErrorAction SilentlyContinue

    if ($valheimProcess) {
        write-host "Running Valheim detected. Stopping this process before upating..."
        Stop-Valheim
    }
    else {
        Write-Host "Updating Valheim..."
        Start-Process "$($config.steamcmd)" -ArgumentList "+login anonymous +force_install_dir $($config.forceinstalldir) +app_update $($config.gameid) validate +exit" -Wait
    }
}

<#
    Stop Valheim by
    sending Ctrl + C to the Valheim window,
    which allows for a clean shutdown
#>
Function Stop-Valheim {
    $valheimProcess = Get-Process valheim_server -ErrorAction SilentlyContinue

    if ($valheimProcess) {
        $valheimProcessID = $valheimProcess.Id
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Add-Type -Names 'w' -Name 'k' -M '[DllImport(""kernel32.dll"")]public static extern bool FreeConsole();[DllImport(""kernel32.dll"")]public static extern bool AttachConsole(uint p);[DllImport(""kernel32.dll"")]public static extern bool SetConsoleCtrlHandler(uint h, bool a);[DllImport(""kernel32.dll"")]public static extern bool GenerateConsoleCtrlEvent(uint e, uint p);public static void SendCtrlC(uint p){FreeConsole();AttachConsole(p);GenerateConsoleCtrlEvent(0, 0);}';[w.k]::SendCtrlC($valheimProcessID)"))

        Start-Process powershell.exe -Argument "-nologo -noprofile -executionpolicy bypass -EncodedCommand $encodedCommand"
        Write-Host "Waiting for process ID: $($valheimProcessID), presumably the Valheim Dedicated Server process, to stop..."
        Wait-Process -ID $valheimProcessID
    }
    else {
        write-host "A running Valheim instance was not detected. The stop process is exiting..."
    }
}

# Get local version
Function Get-Valheim-Local-Version {
    Write-Host "Getting the local version of Valheim..."

    $valheimLocalVersion = (Get-Content "$($config.forceinstalldir)\steamapps\appmanifest_$($config.gameid).acf" | Where-Object { $_ -like "*buildid*" }).Split('"') | Where-Object { $_ -match "^\d+$" }

    Write-Host "The local version of Valheim is: $valheimLocalVersion"
    Return $valheimLocalVersion
}

# Get latest version
Function Get-Valheim-Latest-Version {
    Write-Host "Getting the latest version of Valheim..."

    $steamGameData = Invoke-WebRequest -Uri "https://api.steamcmd.net/v1/info/$($config.gameid)" -UseBasicParsing
    $convertedGameData = $steamGameData.content | ConvertFrom-Json
    $valheimLatestVersion = $convertedGameData.data.($config.gameid).depots.branches.public.buildid

    Write-Host "The latest version of Valheim is: $valheimLatestVersion"
    Return $valheimLatestVersion
}

# Backup world
Function Start-ValheimBackupRegular {
    #This will back up Valheim world
    #Should implement support for -saves parameter in config file and link the backup there if specified.
    
    #Check if backup folder exists. If not, create it.
    if ($config.BackupsFolder) {
        if (!(test-path $config.Backupsfolder)) { New-Item $config.Backupsfolder -ItemType Directory }
    
        $DBFile = Get-ChildItem "$($env:userprofile)\appdata\LocalLow\IronGate\Valheim\worlds\\$($config.world).db"
        $FWLFile = Get-ChildItem "$($env:userprofile)\appdata\LocalLow\IronGate\Valheim\worlds\$($config.world).fwl"
        $Date = get-date $DBFile.LastWriteTime -format "yyyy-MM-dd_HH-mm"
        $Destination = "$($config.Backupsfolder)\$($config.world)\$date"
        $Destination
        if (!(test-path $Destination)) {
            New-Item -Path $Destination -ItemType Directory
            Copy-Item $DBFile -Destination $Destination
            Copy-Item $FWLFile -Destination $Destination
        }
    }
    Else {
        Write-Host "Update config file with BackupsFolder"
    }
}

# Cleanup world backups
Function Start-ValheimBackupCleanup {
    #This will clean up old backups
    
    if ($config.BackupsDaysToKeep) {
        #Check if backup folder exists. If not, create it.
        if (!(test-path $config.Backupsfolder)) { New-Item $config.Backupsfolder -ItemType Directory }
        $DeleteOlderThan = (Get-Date).AddDays( - $($config.BackupsDaysToKeep))
        $FolderToClean = "$($config.Backupsfolder)\$($config.world)"
        Get-ChildItem $FolderToClean | Where-Object { $_.LastWriteTime -lt $DeleteOlderThan } | Remove-Item -Recurse
    }
    Else {
        Write-Host "Update config file with BackupDaysToKeep"
    }
}

# Main
$config = Get-Content "C:\SteamCMD\valheim-oppstallere.config" | ConvertFrom-Json
$welcomeMessage = $true
# Testing individual functions
# $valheimLocalVersion = Get-ValheimLocalVersion
# $valheimRemoteVersion = Get-ValheimLatestVersion
# Stop-Valheim
# Update-Valheim

while ($true) {
    if ($welcomeMessage -eq $true) {
        Write-Host "Valheim Oppstallere: a tool for updating Valheim Dedicated Server, known as just Valheim from here on, is starting..."
    }

    $welcomeMessage = $false
    $valheimLocalVersion = Get-ValheimLocalVersion
    $valheimLatestVersion = Get-ValheimLatestVersion

    if ($valheimLocalVersion -ne $valheimLatestVersion) {
        Write-Host "A new version of Valheim was found. An update will begin..."
        Write-Host "Stopping Valheim..."

        Stop-Valheim

        Write-Host "Updating Valheim..."

        Update-Valheim
    }
    else {
        Write-Host "No new version of Valheim was found. An update is not required."
    }

    # if ($config.BackupsEnabled) {
    #     Start-ValheimBackupRegular
    #     Start-ValheimBackupCleanup
    # }

    # Redundantly start the server
    Start-Valheim

    # Run every 12 hours (43200 seconds)
    Start-Sleep -Seconds 15
}
