<#  
    Oppstallere is a PowerShell script
    derived from tmmjelde's script
    for automatically updating a Valheim dedicated server
    on Windows.
#>

# Start server
Function Start-Valheim {
    $valheimProcess = Get-Process valheim_server -ErrorAction SilentlyContinue

    if ($valheimProcess) {
        write-host "Running Valheim Dedicated Server detected. Skipping start of the process."
    }
    else {
        $env:SteamAppId = "892970"

        white-host "Running Valheim Dedicated Server not detected. Starting the process..."

        Start-Process "$($config.forceinstalldir)\valheim_server.exe" -ArgumentList "-nographics -batchmode -name `"$($config.servername)`" -port $($config.port) -world $($config.world) -password $($config.password)"
    }
}

# Update server
Function Update-Valheim {
    $valheimProcess = get-process valheim_server -ErrorAction SilentlyContinue

    if ($valheimProcess) {
        write-host "Running Valheim Dedicated Server detected. Stopping this process..."
        Stop-Valheim
    }
    else {
        Write-Host "Updating $($config.servername)"
        Start-Process "$($config.steamcmd)" -ArgumentList "+login anonymous +force_install_dir $($config.forceinstalldir) +app_update $($config.gameid) validate +exit" -wait
    }
}

# Stop server
Function Stop-Valheim {
    #Sends Ctrl+C to the Valheim window, which saves the server first and shuts down cleanly
    $Process = get-process valheim_server -ErrorAction SilentlyContinue
    if ($Process) {
        # be sure to set $ProcessID properly. Sending CTRL_C_EVENT signal can disrupt or terminate a process
        $ProcessID = $Process.Id
        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes("Add-Type -Names 'w' -Name 'k' -M '[DllImport(""kernel32.dll"")]public static extern bool FreeConsole();[DllImport(""kernel32.dll"")]public static extern bool AttachConsole(uint p);[DllImport(""kernel32.dll"")]public static extern bool SetConsoleCtrlHandler(uint h, bool a);[DllImport(""kernel32.dll"")]public static extern bool GenerateConsoleCtrlEvent(uint e, uint p);public static void SendCtrlC(uint p){FreeConsole();AttachConsole(p);GenerateConsoleCtrlEvent(0, 0);}';[w.k]::SendCtrlC($ProcessID)"))
        start-process powershell.exe -argument "-nologo -noprofile -executionpolicy bypass -EncodedCommand $encodedCommand"
        write-host "Waiting for Process $($ProcessID) to stop"
        Wait-Process -id $ProcessID
    }
    else {
        write-host "no process found, not terminating anything"
    }
}

# Get local version
Function Get-ValheimLocalVersion {
    Write-Host "Getting the local version of Valheim..."

    $valheimLocalVersion = (Get-Content "$($config.forceinstalldir)\steamapps\appmanifest_$($config.gameid).acf" | Where-Object { $_ -like "*buildid*" }).Split('"') | Where-Object { $_ -match "^\d+$" }

    Write-Host "The local version of Valheim is: $valheimLocalVersion"
    Return $valheimLocalVersion
}

# Get latest remote version
Function Get-ValheimLatestVersion {
    Write-Host "Getting the latest version of Valheim..."

    $steamGameData = Invoke-WebRequest -Uri "https://api.steamcmd.net/v1/info/$($config.gameid)" -UseBasicParsing
    $convertedGameData = $steamGameData.content | ConvertFrom-Json
    $valheimRemoteVersion = $convertedGameData.data.($config.gameid).depots.branches.public.buildid

    Write-Host "The latest version of Valheim is: $valheimRemoteVersion"
    Return $valheimRemoteVersion
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

# Testing individual functions
$valheimLocalVersion = Get-ValheimLocalVersion
$valheimRemoteVersion = Get-ValheimLatestVersion

while ($true) {
    # $valheimRemoteBuild = Get-ValheimLatestVersion
    # $valheimLocalBuild = Get-ValheimLocalVersion
    
    # if ($valheimRemoteBuild -ne $valheimLocalBuild) {
    #     Write-Host "A new build of Valheim was found."
    #     Write-Host "Stopping Valheim..."
    #     Stop-Valheim
    #     Write-Host "Updating Valheim..."
    #     Update-Valheim
    # } else {
    #     Write-Host "No new build of Valheim was found. The current build is: $valheimRemoteBuild"
    # }

    # if ($config.BackupsEnabled) {
    #     Start-ValheimBackupRegular
    #     Start-ValheimBackupCleanup
    # }

    # # This will start Valheim after patching, and even if it's not patched but crashed for some reason
    # Start-Valheim

    # # Will run every 12 hours (43200 seconds)
    # Start-Sleep -Seconds 43200
}
