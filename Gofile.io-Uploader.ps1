$UploadFile = "$args"
$7zExe = "$PSScriptRoot\7z2301-x64\7z.exe"

if((Test-Path -Path "$UploadFile")) {
    $FileBaseName = Get-Item "$UploadFile"
    if($FileBaseName.PSIsContainer) {
        write-host "UploadFile is a Folder"
        $ZipPasswordProtected = $FileBaseName.BaseName + ".zip"
    } else {
        write-host "UploadFile is a File"
        $ZipPasswordProtected = $FileBaseName.BaseName + ".zip"
    }
} else {
    write-host "Error Upload File doesnt exists"
    pause
    exit
}

# https://woshub.com/generating-random-password-with-powershell/
Function GenerateStrongPassword ([Parameter(Mandatory=$true)][int]$PasswordLenght)
{
Add-Type -AssemblyName System.Web
$PassComplexCheck = $false
do {
$newPassword=[System.Web.Security.Membership]::GeneratePassword($PasswordLenght,1)
If ( ($newPassword -cmatch "[A-Z\p{Lu}\s]") `
-and ($newPassword -cmatch "[a-z\p{Ll}\s]") `
-and ($newPassword -match "[\d]") `
-and ($newPassword -match "[^\w]")
)
{
$PassComplexCheck=$True
}
} While ($PassComplexCheck -eq $false)
return $newPassword
}

$ZipPassword = GenerateStrongPassword (20)
write-host $ZipPassword

# https://blog.danskingdom.com/powershell-function-to-create-a-password-protected-zip-file/
function Write-ZipUsing7Zip([string]$FilesToZip, [string]$ZipOutputFilePath, [string]$Password, [ValidateSet('7z','zip','gzip','bzip2','tar','iso','udf')][string]$CompressionType = 'zip', [switch]$HideWindow)
{
    
    if ([string]::IsNullOrEmpty($Password)) {
        throw "Could not find a password"
        pause
        exit
    }

    # Temp Zip Folder
    if((Test-Path -Path "$PSScriptRoot\Temp-Zip")) {
        Remove-Item -Path "$PSScriptRoot\Temp-Zip" -Recurse -Force
    }
    if(!(Test-Path -Path "$PSScriptRoot\Temp-Zip")) {
        New-Item -Path "$PSScriptRoot\Temp-Zip" -ItemType Directory
    }

    # Temp Zip Folder 2
    if((Test-Path -Path "$PSScriptRoot\Temp-Zip-2")) {
        Remove-Item -Path "$PSScriptRoot\Temp-Zip-2" -Recurse -Force
    }
    if(!(Test-Path -Path "$PSScriptRoot\Temp-Zip-2")) {
        New-Item -Path "$PSScriptRoot\Temp-Zip-2" -ItemType Directory
    }

    # Look for the 7zip executable.
    $pathTo64Bit7Zip = "$7zExe"
    $THIS_SCRIPTS_DIRECTORY = Split-Path $script:MyInvocation.MyCommand.Path
    $pathToStandAloneExe = Join-Path $THIS_SCRIPTS_DIRECTORY "7za.exe"
    if (Test-Path $pathTo64Bit7Zip) { $pathTo7ZipExe = $pathTo64Bit7Zip }
    elseif (Test-Path $pathToStandAloneExe) { $pathTo7ZipExe = $pathToStandAloneExe }
    else { 
        throw "Could not find the 7-zip executable."
        pause
        exit
    }

    # Delete the destination zip file if it already exists (i.e. overwrite it).
    if (Test-Path "$PSScriptRoot\Temp-Zip\$ZipOutputFilePath") { Remove-Item "$PSScriptRoot\Temp-Zip\$ZipOutputFilePath" -Force }

    # Delete the destination zip file if it already exists (i.e. overwrite it).
    if (Test-Path "$PSScriptRoot\Temp-Zip-2\$ZipOutputFilePath") { Remove-Item "$PSScriptRoot\Temp-Zip-2\$ZipOutputFilePath" -Force }

    $windowStyle = "Normal"
    if ($HideWindow) { $windowStyle = "Hidden" }

    # Create the arguments to use to zip up the files.
    # Command-line argument syntax can be found at: http://www.dotnetperls.com/7-zip-examples
    $NumberOfCores = (Get-CimInstance –ClassName Win32_Processor).NumberOfCores
    $arguments = "a -t$CompressionType ""$PSScriptRoot\Temp-Zip-2\$ZipOutputFilePath"" ""$FilesToZip"" -mx9 -mmt$NumberOfCores"

    # Zip up the files.
    $pp = Start-Process $pathTo7ZipExe -ArgumentList $arguments -Wait -PassThru -WindowStyle $windowStyle

    # If the files were not zipped successfully.
    if (!(($pp.HasExited -eq $true) -and ($pp.ExitCode -eq 0)))
    {
        throw "There was a problem creating the zip file '$ZipFilePath'."
        pause
        exit
    }

    # Create the arguments to use to zip up the files.
    # Command-line argument syntax can be found at: http://www.dotnetperls.com/7-zip-examples
    $NumberOfCores = (Get-CimInstance –ClassName Win32_Processor).NumberOfCores
    $arguments = "a -t$CompressionType ""$PSScriptRoot\Temp-Zip\$ZipOutputFilePath"" ""$PSScriptRoot\Temp-Zip-2\$ZipOutputFilePath"" -mx1 -mem=AES256 -mmt$NumberOfCores"
    if (!([string]::IsNullOrEmpty($Password))) { $arguments += " -p$Password" }

    # Zip up the files.
    $p = Start-Process $pathTo7ZipExe -ArgumentList $arguments -Wait -PassThru -WindowStyle $windowStyle

    # If the files were not zipped successfully.
    if (!(($p.HasExited -eq $true) -and ($p.ExitCode -eq 0)))
    {
        throw "There was a problem creating the zip file '$ZipFilePath'."
        pause
        exit
    }

    if (Test-Path "$PSScriptRoot\Temp-Zip-2") {
        Remove-Item "$PSScriptRoot\Temp-Zip-2" -Recurse -Force
    } else {
        Write-Host "Temp-Zip-2 folder doesn't exists!"
    }
}

Write-ZipUsing7Zip -FilesToZip "$UploadFile" -ZipOutputFilePath "$ZipPasswordProtected" -Password "$ZipPassword" -HideWindow

$response = Invoke-WebRequest -Uri "https://api.gofile.io/getServer" -Method Get -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36" -DisableKeepAlive -TimeoutSec 10
if ($response.statuscode -eq '200') {
    $keyValue = ConvertFrom-Json $response.Content | Select-Object -expand "data"
    $goFileServer = $keyValue.server
} else {
    Write-Output "Couldnt get a gofile.io upload Server"
    Add-Type -AssemblyName Microsoft.VisualBasic
    $msgBoxInput = [Microsoft.VisualBasic.Interaction]::MsgBox("GoFiles Server Error ! `nStatus Code: $response.statuscode ","Information", "Server Error !!!")
    pause
    exit
}

# Create a new WebClient object
$webClient = New-Object System.Net.WebClient

# Set the User-Agent header
$webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36")

# Upload the file
$response = $webClient.UploadFile("https://$goFileServer.gofile.io/uploadFile", "POST", "$PSScriptRoot\Temp-Zip\$ZipPasswordProtected")

# Convert the response to a string and output it
$Response = [System.Text.Encoding]::UTF8.GetString($response)

$JsonOutput = $Response | ConvertFrom-Json

$goFileStatus = $JsonOutput.status
$goFileId = $JsonOutput.data.fileId
$goFileFileName = $JsonOutput.data.fileName
$goFileUrl = $JsonOutput.data.downloadPage
$fileSize = (Get-Item "$UploadFile").Length
$fileHash = (Get-FileHash -Path "$UploadFile" -Algorithm SHA256).Hash

write-host $goFileStatus
write-host $goFileId
write-host $goFileFileName
write-host $goFileUrl
write-host $fileSize
write-host $fileHash

$HistoryFile = "$PSScriptRoot\GoFile.io-History.txt"
if ($goFileStatus -contains "ok") { 
    write-host "Upload Successfully"
    if(!(Test-Path -Path "$HistoryFile")) {
        Out-File -FilePath "$HistoryFile"
        Write-Output "File '$HistoryFile' created successfully"
    }
    Set-Clipboard -Value "$goFileUrl`n Password: $ZipPassword"
    $TodaysDate = Get-Date
    Add-Content "$HistoryFile" "##############################################################"
    Add-Content "$HistoryFile" "Date: $TodaysDate"
    Add-Content "$HistoryFile" "ID: $goFileId"
    Add-Content "$HistoryFile" "FileName: $goFileFileName"
    Add-Content "$HistoryFile" "FileSize: $fileSize bytes"
    Add-Content "$HistoryFile" "SHA256: $fileHash"
    Add-Content "$HistoryFile" "FilePassword: $ZipPassword"
    Add-Content "$HistoryFile" "DownloadUrl: $goFileUrl"
    Add-Content "$HistoryFile" "##############################################################"
    Add-Content "$HistoryFile" "`n"
    if((Test-Path -Path "$PSScriptRoot\Temp-Zip\$ZipPasswordProtected")) {
        Remove-Item -Path "$PSScriptRoot\Temp-Zip\$ZipPasswordProtected" -Force
    }
    # Auto Close MessageBox after 3 second
    $Body = "$goFileUrl`n Password: $ZipPassword"
    $Shell = new-object -comobject wscript.shell -ErrorAction Stop
    if((Test-Path -Path "$Env:WinDir\Media\tada.wav")) {
        (New-Object Media.SoundPlayer "$Env:WinDir\Media\tada.wav").Play();
    }
    $Disclaimer = $Shell.popup("Downloadlink and Zip Password Copied to Clipboard ! `n`n$Body",3,"File Upload Successful",0)
    $Disclaimer | Out-Null
} else {
    write-host "Upload Error"
    if((Test-Path -Path "$PSScriptRoot\Temp-Zip\$ZipPasswordProtected")) {
        Remove-Item -Path "$PSScriptRoot\Temp-Zip\$ZipPasswordProtected" -Force
    }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $msgBoxInput = [Microsoft.VisualBasic.Interaction]::MsgBox("GoFiles Upload Error ! `n$Response ","Information", "Upload Failed !!!")
    pause
    exit
}

exit
