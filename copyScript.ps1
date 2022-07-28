function Split-File {
    param (
        [Parameter(Mandatory)]
        [String]
        $Path,

        [Int32]
        $PartsSizeBytes = 10MB
    )

    try {
        #Getting the path to construct the individual part
        #filenames:
        $fullBaseName = [IO.Path]::GetFileName($Path)
        $baseName = [IO.Path]::GetFileNameWithoutExtension($Path)
        $parentFolder = [IO.Path]::GetDirectoryName($Path)
        $ext = [IO.Path]::GetExtension($Path)

        #Get the origional file size and calculate the required parts
        $origionalFile = New-Object System.IO.FileInfo($Path)
        $totChunks = [int]($origionalFile.Length / $PartsSizeBytes) + 1
        $digitCount = [int][Math]::Log10($totChunks) + 1

        #read the origional file and split into chunks
        $reader = [IO.File]::OpenRead($Path)
        $count = 0
        $partCounter = 1
        $buffer = New-Object Byte[] $PartsSizeBytes
        $moreData = $true

        while($moreData) {
            #read a chunk
            $bytesRead = $reader.Read($buffer, 0,$buffer.Length)
            #create the filename for the chunk file
            $chunkFileName = "$parentFolder\$fullBaseName.$partCounter.part" -f $count
            Write-Verbose "Saving to $chunkFileName..."
            $output = $buffer
            #did we read to little of info?
            if ($bytesRead -ne $buffer.Length) {
                #Yes, so there is no more data
                $moreData = $false #shrink the output array to the number of bytes actually read:
                $output = New-Object Byte[] $bytesRead
                [Array]::Copy($buffer,$output,$bytesRead)
            }
            #Save the read bytes in a new part file
            [IO.File]::WriteAllBytes($chunkFileName, $output)
            #increase counter
            ++$counter
            ++$partCounter
        }
        $reader.Close()
    } catch {
        throw "Unable to split file ${Path}: $_"
    }
}
function Join-File
{
    
    param
    (
        [Parameter(Mandatory)]
        [String]
        $Path,

        [Switch]
        $DeletePartFiles
    )

    try
    {
        # get the file parts
        $files = Get-ChildItem -Path "$Path.*.part" | 
        # sort by part 
        Sort-Object -Property {
            # get the part number which is the "extension" of the
            # file name without extension
            $baseName = [IO.Path]::GetFileNameWithoutExtension($_.Name)
            $part = [IO.Path]::GetExtension($baseName)
            if ($part -ne $null -and $part -ne '')
            {
                $part = $part.Substring(1)
            }
            [int]$part
        }
        # append part content to file
        $writer = [IO.File]::OpenWrite($Path)
        $files |
        ForEach-Object {
            Write-Verbose "processing $_..."
            $bytes = [IO.File]::ReadAllBytes($_)
            $writer.Write($bytes, 0, $bytes.Length)
        }
        $writer.Close()

        if ($DeletePartFiles)
        {
            Write-Verbose "Deleting part files..."
            $files | Remove-Item
        }
    }
    catch
    {
        throw "Unable to join part files: $_"
    }
}
#Name: Tyler Dickard
#Date: 7/27/2022
#Description: This is a basic test script to copy files from one folder to another folder.
#*************************************************************************************************
#All of the Add-Types for this project
#*************************************************************************************************
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
#*************************************************************************************************
#Checks for internet connection by pinging an IP address
#*************************************************************************************************

##if(-not (Test-NetConnection) -ccontains "PingSucceeded          : True") {
  ##  throw
##}
#*************************************************************************************************
#Generates the form
#*************************************************************************************************
$form = New-Object System.Windows.Forms.Form
$form.Text = "Transfer Tool"
$form.Size = New-Object System.Drawing.Size(400,120)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
#*************************************************************************************************
#Generates the information label
#*************************************************************************************************
$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(0,0)
$lblInfo.Size = New-Object System.Drawing.Size(400,20)
$lblInfo.Text = 'Is this an upload or download of a .pst file?'
$form.Controls.Add($lblInfo)
#*************************************************************************************************
#Generates the radio button for the upload
#*************************************************************************************************
$rbtnUpload = New-Object System.Windows.Forms.RadioButton
$rbtnUpload.Location = New-Object System.Drawing.Point(0,20)
$rbtnUpload.Size = New-Object System.Drawing.Size(400,20)
$rbtnUpload.Text = "Upload"
$rbtnUpload.Checked = $true
$form.Controls.Add($rbtnUpload)
#*************************************************************************************************
#Generates the radio button for download
#*************************************************************************************************
$rbtnDownload = New-Object System.Windows.Forms.RadioButton
$rbtnDownload.Location = New-Object System.Drawing.Point(0,40)
$rbtnDownload.Size = New-Object System.Drawing.Size(400,20)
$rbtnDownload.Text = "Download"
$form.Controls.Add($rbtnDownload)
#*************************************************************************************************
#Button to iniate the transfer process
#*************************************************************************************************
$btnTransfer = New-Object System.Windows.Forms.Button
$btnTransfer.Location = New-Object System.Drawing.Point(0,60)
$btnTransfer.Size = New-Object System.Drawing.Size(55,20)
$btnTransfer.Text = 'Transfer'
$btnTransfer.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $btnTransfer
$form.Controls.Add($btnTransfer)
#*************************************************************************************************
#Makes the form overlap any other window when running
#*************************************************************************************************
$form.Topmost = $true
#*************************************************************************************************
#Gets the result from the form, i.e. when the button is pressed
#*************************************************************************************************
$result = $form.ShowDialog()
#*************************************************************************************************
#Makes the form wait until the user hits the button
#*************************************************************************************************
while(-not $result -eq [System.Windows.Forms.DialogResult]::OK) {
    Start-Sleep -Milliseconds 1
} 
#*************************************************************************************************
#Checks if the result is OK, if so it will then check the text boxes to have some sort of input
#if there isnt any input it will error out, but if it does have input it will attempt to do a transfer
#from one device to another utilizing the secret share drive
#*************************************************************************************************
if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{ 
    if( ($rbtnUpload.Checked -eq $true)) {
        $sourcePart = "C:\Users\$env:UserName\Documents\Outlook Files\backup.pst"
        Split-File -Path $sourcePart -Verbose
        Remove-Item -Path "C:\Users\$env:UserName\Documents\Outlook Files\backup.pst"
        Get-ChildItem -Path "C:\Users\$env:UserName\Documents\Outlook Files\" -Filter *.part | ForEach-Object {
            Compress-Archive -Path $_.FullName  -Destination "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\$_.zip" -CompressionLevel Optimal 
            Remove-Item $_.FullName
        }
        Compress-Archive -Path "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\*.zip" -Destination "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\outlookArchive.zip"  -CompressionLevel Optimal
        Copy-Item -Path "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\outlookArchive.zip" -Destination "C:\Users\$env:UserName\OneDrive - MMO"
        Remove-Item -Path "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\." -Include *.zip  -Force -Recurse
        $form.Close();
    } elseif ($rbtnDownload.Checked -eq $true) {
        while(-not ((Test-Path -Path "C:\Users\$env:UserName\OneDrive - MMO\outlookArchive.zip" -PathType Leaf) -eq $true)) {
            Start-Sleep -Milliseconds 1
        }
        Copy-Item -Path "C:\Users\$env:UserName\OneDrive - MMO\outlookArchive.zip" -Destination "C:\Users\$env:UserName\Documents\Outlook Files\"
        Remove-Item -Path "C:\Users\$env:UserName\OneDrive - MMO\outlookArchive.zip"
        Expand-Archive -Path "C:\Users\$env:UserName\Documents\Outlook Files\outlookArchive.zip" -Destination "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\"
        Remove-Item -Path "C:\Users\$env:UserName\Documents\Outlook Files\outlookArchive.zip"
        Get-ChildItem -Path "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\" -Filter *.zip | ForEach-Object {
            Expand-Archive -Path $_.FullName  -Destination "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\"
            Remove-Item $_.FullName
        }
        Join-File "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\backup.pst" -DeletePartFiles -Verbose
        Remove-Item -Path "C:\Users\$env:UserName\AppData\Local\Microsoft\Outlook\*.zip" -Force

    } else {
        Write-Warning "ERROR: radio button is not checked. I'm not sure how you managed to do this, but please report it to IT :)"
        $form.Close();
        Start-Sleep -Seconds 2
        Exit
    }
}