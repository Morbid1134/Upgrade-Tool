Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Self Elevation (works in PS1 and EXE) ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole] "Administrator")) {

    # Determine the running executable
    $exePath = $null
    if ($PSVersionTable.PSVersion.Major -ge 5 -and $MyInvocation.MyCommand.Definition.EndsWith(".ps1")) {
        # Running as a PS1 file
        $exeCandidate = [System.IO.Path]::ChangeExtension($MyInvocation.MyCommand.Definition, "exe")
        if (Test-Path $exeCandidate) { $exePath = $exeCandidate } else { $exePath = $MyInvocation.MyCommand.Definition }
    } else {
        # Running as a compiled EXE
        $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }

    Start-Process -FilePath $exePath -Verb RunAs
    exit
}



# --- Form ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Windows 11 Upgrade Utility"
$Form.Size = New-Object System.Drawing.Size(640,500)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$Form.MaximizeBox = $false
$Form.MinimizeBox = $false
$Form.BackColor = [System.Drawing.Color]::WhiteSmoke

# --- Output Box ---
$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = "Vertical"
$OutputBox.ReadOnly = $true
$OutputBox.WordWrap = $true
$OutputBox.Font = New-Object System.Drawing.Font("Consolas",10)
$OutputBox.Size = New-Object System.Drawing.Size(580,350)
$OutputBox.Location = New-Object System.Drawing.Point(20,20)
$Form.Controls.Add($OutputBox)

# --- Buttons ---
$RunButton = New-Object System.Windows.Forms.Button
$RunButton.Text = "Start Upgrade"
$RunButton.Location = New-Object System.Drawing.Point(20,390)
$RunButton.Size = New-Object System.Drawing.Size(150,40)
$Form.Controls.Add($RunButton)

$ExitButton = New-Object System.Windows.Forms.Button
$ExitButton.Text = "Exit"
$ExitButton.Location = New-Object System.Drawing.Point(200,390)
$ExitButton.Size = New-Object System.Drawing.Size(100,40)
$ExitButton.Add_Click({ $Form.Close() })
$Form.Controls.Add($ExitButton)

# --- Logging Helper ---
function Write-Log {
    param([string]$text)
    $OutputBox.AppendText("$text`r`n")
    $OutputBox.SelectionStart = $OutputBox.Text.Length
    $OutputBox.ScrollToCaret()
    $OutputBox.Refresh()
}

# --- Upgrade Logic ---
$RunButton.Add_Click({

    $RunButton.Enabled = $false
    Write-Log "=== Windows 11 Upgrade Automation ==="

    try {
        # --- Check PortableOperatingSystem Registry Key ---
        Write-Log "Checking PortableOperatingSystem registry key..."
        $regPath = "HKLM:\System\CurrentControlSet\Control"
        $regKey = "PortableOperatingSystem"
        
        try {
            $regValue = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue
            if ($regValue) {
                if ($regValue.$regKey -ne 0) {
                    Write-Log "PortableOperatingSystem is set to $($regValue.$regKey). Setting to 0..."
                    Set-ItemProperty -Path $regPath -Name $regKey -Value 0
                    Write-Log "PortableOperatingSystem has been set to 0."
                } else {
                    Write-Log "PortableOperatingSystem is already set to 0."
                }
            } else {
                Write-Log "PortableOperatingSystem registry key does not exist. Skipping..."
            }
        } catch {
            Write-Log "Warning: Could not access registry: $($_.Exception.Message)"
        }

        # --- Detect Boot Disk ---
        $disk = Get-Disk | Where-Object { $_.IsBoot -eq $true }
        if (-not $disk) { throw "No boot disk detected!" }
        $disk = $disk[0]
        $osDrive = (Get-WmiObject Win32_OperatingSystem).SystemDrive.TrimEnd(":")
        Write-Log "System drive: $osDrive`:"
        Write-Log "Boot Disk: $($disk.Number) ($($disk.PartitionStyle))"

        # --- Handle MBR ---
        if ($disk.PartitionStyle -eq "MBR") {
            Write-Log "MBR detected. Validating disk for GPT conversion..."
            $validate = Start-Process -FilePath "mbr2gpt.exe" -ArgumentList "/validate","/disk:$($disk.Number)","/allowfullos" -Wait -PassThru
            Write-Log "mbr2gpt validation exit code: $($validate.ExitCode)"

            if ($validate.ExitCode -ne 0) {
                [System.Windows.Forms.MessageBox]::Show("Disk cannot be safely converted to GPT.","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }

            $ans = [System.Windows.Forms.MessageBox]::Show("Convert disk $($disk.Number) to GPT now?","MBR Detected",[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
            if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
                Write-Log "Converting disk..."
                $convert = Start-Process -FilePath "mbr2gpt.exe" -ArgumentList "/convert","/disk:$($disk.Number)","/allowfullos" -Wait -PassThru
                Write-Log "mbr2gpt convert exit code: $($convert.ExitCode)"
                if ($convert.ExitCode -ne 0) {
                    [System.Windows.Forms.MessageBox]::Show("Conversion failed. Check logs.","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
                    return
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Conversion successful. Please reboot and rerun the tool.","Success",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)
                    return
                }
            } else {
                Write-Log "User declined conversion."
                return
            }
        }

        Write-Log "Disk is GPT. Proceeding with upgrade."

        # --- User selects ISO ---
        $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $OpenFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        $OpenFileDialog.Filter = "ISO Files (*.iso)|*.iso"
        $OpenFileDialog.Multiselect = $false
        $OpenFileDialog.Title = "Select Windows 11 ISO"

        $DialogResult = $OpenFileDialog.ShowDialog()
        if ($DialogResult -ne [System.Windows.Forms.DialogResult]::OK) {
            Write-Log "No ISO selected. Exiting."
            return
        }

        $isoSource = $OpenFileDialog.FileName
        $isoName = Split-Path $isoSource -Leaf
        $isoDest = "$osDrive`:\$isoName"

        Write-Log "Selected ISO: $isoName"

        # --- Check if ISO is already on OS drive ---
        if ($isoSource -eq $isoDest) {
            Write-Log "ISO is already on $osDrive`:\. Skipping copy."
        } else {
            Write-Log "Copying ISO to $isoDest ..."

            # --- Capture verbose copy output ---
            $verboseOutput = Copy-Item $isoSource $isoDest -Force -Verbose 4>&1
            foreach ($line in $verboseOutput) {
                Write-Log $line
            }

            Write-Log "Copy complete."
        }

        # --- Mount ISO ---
        Write-Log "Mounting ISO..."
        $volBefore = Get-Volume | Select-Object -ExpandProperty DriveLetter
        Mount-DiskImage -ImagePath $isoDest -ErrorAction Stop
        Start-Sleep 3
        $volAfter = Get-Volume | Select-Object -ExpandProperty DriveLetter
        $letter = ($volAfter | Where-Object { $volBefore -notcontains $_ } | Select-Object -First 1)
        if (-not $letter) { throw "Failed to detect mounted ISO drive letter!" }
        Write-Log "ISO mounted as $letter`:"
        $setupPath = "$letter`:\Sources\setupprep.exe"
        if (-not (Test-Path $setupPath)) { throw "setupprep.exe not found in ISO!" }

        # --- Launch Setup ---
        Write-Log "Launching Windows 11 setup..."
        Start-Process -FilePath $setupPath -ArgumentList "/product server"
        Write-Log "Setup started successfully. USB can be removed."
        [System.Windows.Forms.MessageBox]::Show("Setup started successfully. USB can be removed.","Complete",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information)

    } catch {
        $msg = $_.Exception.Message
        Write-Log "[ERROR] $msg"
        [System.Windows.Forms.MessageBox]::Show("An error occurred: $msg","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error)
    } finally {
        $RunButton.Enabled = $true
    }

})

# --- Run Form ---
[void]$Form.ShowDialog()
