# ============================================
# Microsoft Store Manager Script
# ============================================
# Sources:
# 1. PowerShell commands to remove Microsoft Store: 
#    https://forums.mydigitallife.net/threads/guide-add-store-to-windows-10-enterprises-sku-ltsb-ltsc.70741/page-30#post-1468779
#    Credit: abbodi1406 from MyDigitalLife forums
# 2. wsreset to reinstall Microsoft Store:
#    https://forums.mydigitallife.net/threads/guide-add-store-to-windows-10-enterprises-sku-ltsb-ltsc.70741/page-55#post-1711200
#    Credit: Applegame12345 from MDL

# Clear the screen
Clear-Host

# Display the options
Write-Host "==============================="
Write-Host "   Microsoft Store Manager    "
Write-Host "==============================="
Write-Host ""
Write-Host "1. Remove Microsoft Store"
Write-Host "2. Install Microsoft Store"
Write-Host ""

# Prompt the user to select an option
$choice = Read-Host "Please choose an option (1 or 2)"

# Remove Microsoft Store
if ($choice -eq "1") {
    Write-Host "Removing Microsoft Store..." -ForegroundColor Cyan

    try {
        # Remove the AppX Package for all users
        $WindowsStore = 'Microsoft.WindowsStore'
        Get-AppXPackage -AllUsers | Where-Object { $_.Name -match $WindowsStore } | Remove-AppxPackage -AllUsers

        # Remove the AppX Provisioned Package for all users
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match $WindowsStore } | Remove-AppxProvisionedPackage -Online

        Write-Host "Microsoft Store has been successfully removed." -ForegroundColor Green
    } catch {
        Write-Host "An error occurred while removing Microsoft Store." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    # Exit the script
    return
}

# Install Microsoft Store using wsreset
elseif ($choice -eq "2") {
    Write-Host "Installing Microsoft Store..." -ForegroundColor Cyan

    try {
        # Run wsreset to reinstall the Microsoft Store
        Start-Process "wsreset.exe" -ArgumentList "-i" -Wait

        Write-Host "Microsoft Store has been successfully reinstalled." -ForegroundColor Green

        # Inform the user to wait for the store to appear
        Write-Host "Please wait 1-2 minutes for the Microsoft Store to fully load." -ForegroundColor Yellow

    } catch {
        Write-Host "An error occurred while installing Microsoft Store using wsreset." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }

    # Exit the script
    return
}

# Invalid choice
else {
    Write-Host "Invalid choice. Please run the script again and choose either 1 or 2." -ForegroundColor Red
    return
}