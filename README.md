# Windows 11 Upgrade Utility

A PowerShell automation tool designed to simplify and streamline the Windows 11 upgrade process. This utility handles disk preparation, registry validation, ISO mounting, and automated Windows 11 setup initiation.

## Features

- **Automatic Administrator Elevation**: Prompts for elevated privileges if not already running as administrator
- **Registry Validation**: Checks and corrects the `PortableOperatingSystem` registry key to ensure upgrade compatibility
- **Disk Detection**: Automatically detects the boot disk and validates partition scheme
- **MBR to GPT Conversion**: Automatically detects MBR disks and guides users through GPT conversion using `mbr2gpt.exe`
- **Smart ISO Handling**: 
  - Allows users to select a Windows 11 ISO file
  - Skips copying if the ISO is already on the OS drive
  - Copies ISO to OS drive for faster access if needed
- **ISO Mounting**: Automatically mounts the ISO and detects the assigned drive letter
- **Windows Setup Launch**: Initiates the Windows 11 setup with server product configuration
- **Detailed Logging**: Real-time progress display in a user-friendly GUI

## System Requirements

- **OS**: Windows 10 or Windows 11
- **Architecture**: x64
- **Privileges**: Administrator rights (required)
- **PowerShell**: Version 5.0 or higher
- **Disk Space**: Sufficient space to temporarily store the Windows 11 ISO (typically 5-6 GB)
- **Partition Table**: MBR or GPT (MBR will be converted to GPT if necessary)

## Installation

### Option 1: Run as PowerShell Script (Recommended for Testing)

1. Save `UpgradeTool.ps1` to your desired location
2. Right-click on `UpgradeTool.ps1` and select "Open with PowerShell"
3. If prompted about execution policy, you may need to allow script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Option 2: Convert to Executable with PS2EXE (Recommended for Deployment)

PS2EXE is a tool that compiles PowerShell scripts into standalone executables. This is ideal for deployment and user distribution.

**Steps to create an EXE:**

1. Install PS2EXE from the PowerShell Gallery:
   ```powershell
   Install-Module ps2exe -Force
   ```

2. Compile the script to an executable:
   ```powershell
   Invoke-ps2exe -inputFile "C:\path\to\UpgradeTool.ps1" -outputFile "C:\path\to\UpgradeTool.exe" -iconFile "C:\path\to\icon.ico" (optional)
   ```

3. Run `UpgradeTool.exe` directly from Windows Explorer

**Note**: The script includes automatic elevation logic that works seamlessly with both the `.ps1` and `.exe` versions.

## Usage

1. **Start the Tool**: 
   - Launch `UpgradeTool.ps1` or `UpgradeTool.exe`
   - You will be prompted to run as administrator if not already elevated

2. **Registry Check**: 
   - The tool automatically checks for the `PortableOperatingSystem` registry key at `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control`
   - If found and not set to `0`, it will be corrected automatically
   - If not found, the tool continues without action

3. **Disk Validation**: 
   - The tool detects your boot disk and partition scheme
   - **If MBR is detected**: You'll be prompted to convert to GPT (required for Windows 11)
     - Choose "Yes" to convert now (restart required after conversion)
     - Choose "No" to cancel the upgrade process
   - **If GPT is detected**: The tool proceeds directly to ISO selection

4. **ISO Selection**: 
   - A file browser will open (defaulting to Desktop)
   - Select your Windows 11 ISO file
   - The tool will automatically copy the ISO to your OS drive if not already present
   - If the ISO is already on the OS drive, copying is skipped

5. **ISO Mounting & Setup Launch**: 
   - The ISO is mounted automatically
   - Windows 11 setup is launched with server product configuration
   - A completion message confirms successful initialization

## Workflow Diagram

```
┌─────────────────────────┐
│  Start UpgradeTool      │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Prompt for Administrator Elevation │
└────────────┬────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────┐
│  Check PortableOperatingSystem Registry  │
│  (Set to 0 if necessary)                 │
└────────────┬─────────────────────────────┘
             │
             ▼
┌─────────────────────────────┐
│  Detect Boot Disk           │
└────────────┬────────────────┘
             │
             ▼
      ┌──────────────┐
      │ Disk Format? │
      └──┬────────┬──┘
    MBR │        │ GPT
        │        │
        ▼        ▼
    ┌────┐  ┌──────────────────────────────┐
    │MBR │  │ Proceed to ISO Selection     │
    │Conv│  │ - User selects Windows 11 ISO
    │    │  │ - Copy ISO to OS drive (if needed)
    │    │  │ - Mount ISO
    │    │  │ - Launch Windows 11 Setup
    └────┘  └──────────────────────────────┘
```

## Common Scenarios

### Scenario 1: Using an ISO from External USB
- Select the ISO from the external USB when prompted
- The tool copies it to your OS drive for faster access
- Setup proceeds normally

### Scenario 2: ISO Already on OS Drive
- Select the ISO when prompted
- The tool detects it's already on the OS drive
- Copy step is skipped, saving time
- Setup proceeds immediately

### Scenario 3: MBR Disk Detected
- The tool validates the disk for conversion
- If validation passes, you're asked to approve conversion
- After conversion, you must restart the computer
- Rerun the tool after restart to continue

### Scenario 4: PortableOperatingSystem Key is Set
- The tool detects the registry key
- Automatically corrects it to `0`
- Upgrade process continues normally

## Troubleshooting

### "No boot disk detected!"
- Ensure your system disk is properly recognized
- Check BIOS settings for disk detection
- Try restarting the computer

### "Disk cannot be safely converted to GPT"
- The disk contains data that cannot be safely converted
- Back up critical data to external storage
- Consider a clean installation instead

### "Failed to detect mounted ISO drive letter!"
- The ISO mounting may have failed
- Check that sufficient disk space is available
- Ensure the ISO file is not corrupted
- Try mounting the ISO manually using File Explorer

### "setupprep.exe not found in ISO!"
- The selected file may not be a valid Windows 11 ISO
- Verify the ISO integrity
- Download a fresh copy of the Windows 11 ISO from Microsoft
- Ensure you selected the correct ISO file

### Execution Policy Error
If you see "cannot be loaded because running scripts is disabled", run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Access Denied" Errors
- Ensure you're running as administrator
- The tool will automatically prompt for elevation, but ensure it's allowed
- Check User Account Control (UAC) settings

## Technical Details

### Registry Paths
- **PortableOperatingSystem**: `HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\PortableOperatingSystem`

### System Commands Used
- `mbr2gpt.exe`: Converts MBR disks to GPT
- `setupprep.exe`: Windows 11 setup engine (from ISO)
- `Get-Disk`: PowerShell cmdlet for disk detection
- `Mount-DiskImage`: PowerShell cmdlet for ISO mounting
- `Get-Volume`: PowerShell cmdlet for volume detection

### GUI Components
- **Output Box**: Displays operation logs
- **Start Upgrade Button**: Initiates the upgrade process
- **Exit Button**: Closes the tool

## Safety Considerations

⚠️ **Important**: This tool is designed for professional system administrators and advanced users.

- **Backup Important Data**: Always create a backup before running disk operations
- **Test in Lab Environment**: Test this tool on non-production systems first
- **Monitor Disk Space**: Ensure sufficient space for ISO copying and upgrade
- **Network Connection**: No need for any network connection during setup (during installation network required for updates)
- **Power Supply**: Connect to stable power (do not want to run out of battery during an upgrade)

## Support for Both .ps1 and .exe

This script includes intelligent logic to work seamlessly in both formats:

- **When run as .ps1**: Detects if an `.exe` version exists and uses it for elevation if needed
- **When run as .exe** (compiled with PS2EXE): Uses the `.exe` for elevation

This dual-mode support ensures consistent behavior regardless of execution method.

## Version History

- **v1.0** - Initial release
  - Basic upgrade automation
  - MBR to GPT conversion
  - ISO selection and mounting
  - Setup initiation

- **v1.1** - Registry and optimization improvements
  - Added PortableOperatingSystem registry check
  - Smart ISO copying (skip if already on OS drive)
  - Enhanced error handling

## License

This tool is provided as-is for system administration purposes. Modify and distribute as needed within your organization.

## Author Notes

This tool was designed to automate recurring Windows 11 upgrades. 
The goal of this tool is to have a simple executable any technician can use to upgrade any Windows 10 machine to Windows 11 without needing to know archaic issues as the script will check and resolve as much as it can automatically.

---
