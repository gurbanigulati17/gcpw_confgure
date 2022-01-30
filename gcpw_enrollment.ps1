<# This script downloads Google Credential Provider for Windows from
https://tools.google.com/dlpage/gcpw/, then installs and configures it.
Windows administrator access is required to use the script.
If Chrome enterprise is not present, it will also download and install it
and it will enroll them to the Chrome Enterprise
#>

<# Specify a -user parameter if you want to bind the current user account to a Google account.
-User name.lastname@domain.com -> to specify email to enroll current windows account
-MDMvalue 1 -> to enable automatic MDM Enrollment to Google Endpoint Management
-ValidityPeriod 30 -> To change the number of days an account can be used without connecting to Google
Run the script like below, make sure you check the parameters:
powershell.exe -ExecutionPolicy Unrestricted -NoLogo -NoProfile -Command "& '.\gcpw_enrollment.ps1' -User name.lastname@domain.com -MDMvalue 1"
#>

<# Default Params #>
param (
    [string]$User = ""
    [int]$MDMvalue = 0,
    [int]$ValidityPeriod = 30
)

<# Add domains to restrict here #>
$domainsAllowedToLogin = "natran.com"
<# Faster downloads with Invoke-WebRequest #>
$ProgressPreference = 'SilentlyContinue'
<# Chrome Enterprise Enrollment token #>
$enrollmentToken = '5db2f5fe-3938-4929-8414-e31f292f9cde'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

<# Check if one or more domains are set #>
if ($domainsAllowedToLogin.Equals('')) {
    # $msgResult = [System.Windows.MessageBox]::Show('The list of domains cannot be empty! Please edit this script.', 'GCPW', 'OK', 'Error')
    Write-Output 'The list of domains cannot be empty! Please edit this script.'
    exit 5
}

function Is-Admin() {
    $admin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')
    return $admin
}

<# Check if the current user is an admin and exit if they aren't. #>
if (-not (Is-Admin)) {
    # $result = [System.Windows.MessageBox]::Show('Please run as administrator!', 'GCPW', 'OK', 'Error')
    Write-Output 'Please run as administrator!'
    exit 5
}

if (!(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName -match "Google Chrome" })) {
    <# Choose the Chrome file to download. 32-bit and 64-bit versions have different names #>
    $chromeFileName = 'googlechromestandaloneenterprise.msi'
    if ([Environment]::Is64BitOperatingSystem) {
        $chromeFileName = 'googlechromestandaloneenterprise64.msi'
    }

    <# Download the Chrome installer. #>
    $chromeUrlPrefix = 'https://dl.google.com/chrome/install/'
    $chromeUri = $chromeUrlPrefix + $chromeFileName
    Write-Host 'Downloading Chrome from' $chromeUri
    Invoke-WebRequest -Uri $chromeUri -OutFile "$env:temp\$chromeFileName"

    <# Run the Chrome installer and wait for the installation to finish #>
    $arguments = "/i `"$env:temp\$chromeFileName`" /qn"
    $installProcess = (Start-Process msiexec.exe -ArgumentList $arguments -PassThru -Wait)

    <# Check if installation was successful #>
    if ($installProcess.ExitCode -ne 0) {
        # $result = [System.Windows.MessageBox]::Show('Installation failed!', 'Chrome', 'OK', 'Error')
        exit $installProcess.ExitCode
    }
    else {
        Write-Host 'Chrome successfully installed'
        # $result = [System.Windows.MessageBox]::Show('Installation completed successfully!', 'Chrome', 'OK', 'Info')
        # Apply local Chrome Enterprise settings for enrollment
        Write-Output 'Enforcing Chrome Enterprise Config'
        $key = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -Path $key -Name 'CloudManagementEnrollmentMandatory' -Value 1 -PropertyType 'DWord' -Force | Out-Null
        New-ItemProperty -Path $key -Name 'CloudManagementEnrollmentToken' -Value $enrollmentToken -Force | Out-Null
        New-ItemProperty -Path $key -Name 'BrowserSignin' -Value 2 -PropertyType 'DWord' -Force | Out-Null
        New-ItemProperty -Path $key -Name 'RestrictSigninToPattern' -Value '' -Force | Out-Null
        New-ItemProperty -Path $key -Name 'AllowedDomainsForApps' -Value '' -Force | Out-Null
        New-ItemProperty -Path $key -Name 'CloudPolicyOverridesPlatformPolicy' -Value 1 -PropertyType 'DWord' -Force | Out-Null
        New-ItemProperty -Path $key -Name 'DefaultBrowserSettingEnabled' -Value 1 -PropertyType 'DWord' -Force | Out-Null
        New-ItemProperty -Path $key -Name 'PasswordLeakDetectionEnabled' -Value 1 -PropertyType 'DWord' -Force | Out-Null
        New-ItemProperty -Path $key -Name 'RelaunchNotification' -Value 2 -PropertyType 'DWord' -Force | Out-Null

        Write-Output 'Chrome Enterprise installed and enrolled.'
    }

}else {
    Write-Output 'Chrome Enterprise alreaday installed. Skipping...'
}

if (!(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Where-Object { $_.DisplayName -match "Google Credential Provider for Windows" })) {
    <# Choose the GCPW file to download. 32-bit and 64-bit versions have different names #>
    $gcpwFileName = 'gcpwstandaloneenterprise.msi'
    if ([Environment]::Is64BitOperatingSystem) {
        $gcpwFileName = 'gcpwstandaloneenterprise64.msi'
    }

    <# Download the GCPW installer. #>
    $gcpwUrlPrefix = 'https://dl.google.com/credentialprovider/'
    $gcpwUri = $gcpwUrlPrefix + $gcpwFileName
    Write-Host 'Downloading GCPW from' $gcpwUri
    Invoke-WebRequest -Uri $gcpwUri -OutFile "$env:temp\$gcpwFileName"

    <# Run the GCPW installer and wait for the installation to finish #>
    $arguments = "/i `"$env:temp\$gcpwFileName`" /quiet"
    $installProcess = (Start-Process msiexec.exe -ArgumentList $arguments -PassThru -Wait)

    <# Check if installation was successful #>
    if ($installProcess.ExitCode -ne 0) {
        # $result = [System.Windows.MessageBox]::Show('Installation failed!', 'GCPW', 'OK', 'Error')
        Write-Output 'Installation failed!'
        exit $installProcess.ExitCode
    }
    else {
        # $result = [System.Windows.MessageBox]::Show('Installation completed successfully!', 'GCPW', 'OK', 'Info')
        Write-Output 'Installation completed successfully!'
    }
} else {
    Write-Output 'GCPW alreaday installed. Skipping...'
}

<# Set the required registry key with the allowed domains #>
$registryPath = 'HKEY_LOCAL_MACHINE\Software\Google\GCPW'
$name = 'domains_allowed_to_login'
[microsoft.win32.registry]::SetValue($registryPath, $name, $domainsAllowedToLogin)

$domains = Get-ItemPropertyValue HKLM:\Software\Google\GCPW -Name $name

if ($domains -eq $domainsAllowedToLogin) {
    # $msgResult = [System.Windows.MessageBox]::Show('Configuration completed successfully!', 'GCPW', 'OK', 'Info')
    Write-Output 'Domain configuration completed successfully!'
}
else {
    # $msgResult = [System.Windows.MessageBox]::Show('Could not write to registry. Configuration was not completed.', 'GCPW', 'OK', 'Error')
    Write-Output "Could not write domain configuration to registry. Configuration was not completed. ($domains - $domainsAllowedToLogin)"
}

<# Set the validity, time accounts are allowed to be offline #>
$name = 'validity_period_in_days'
$value = $ValidityPeriod
[microsoft.win32.registry]::SetValue($registryPath, $name, $value)

$validity = Get-ItemPropertyValue HKLM:\Software\Google\GCPW -Name $name

if ($validity -eq $value) {
    # $msgResult = [System.Windows.MessageBox]::Show('Configuration completed successfully!', 'GCPW', 'OK', 'Info')
    Write-Output 'Validity configuration completed successfully!'
}
else {
    # $msgResult = [System.Windows.MessageBox]::Show('Could not write to registry. Configuration was not completed.', 'GCPW', 'OK', 'Error')
    Write-Output "Could not write validity to registry. Configuration was not completed. ($domains - $domainsAllowedToLogin)"
}

<# Set MDM enrollment #>
Write-Output "Setting MDM value to $MDMvalue"
$name = 'enable_dm_enrollment'
[microsoft.win32.registry]::SetValue($registryPath, $name, $MDMvalue)

$validity = Get-ItemPropertyValue HKLM:\Software\Google\GCPW -Name $name

if ($validity -eq $MDMvalue) {
    # $msgResult = [System.Windows.MessageBox]::Show('Configuration completed successfully!', 'GCPW', 'OK', 'Info')
    Write-Output 'MDM enrollment configuration completed successfully!'
}
else {
    # $msgResult = [System.Windows.MessageBox]::Show('Could not write to registry. Configuration was not completed.', 'GCPW', 'OK', 'Error')
    Write-Output "Could not write MDM enrollment to registry. Configuration was not completed. (MDM -> $MDMvalue)"
}

<# if $User is set to a valid Google email account, the current account will be tied to it #>
if ($User) {
    Write-Output "Setting user to $User"
    $currentSid = Get-CimInstance Win32_UserAccount -Filter "Name = '$env:USERNAME'" | Select-Object -ExpandProperty SID
    $registryPath = "HKEY_LOCAL_MACHINE\Software\Google\GCPW\Users\" + $currentSid
    $name = 'email'
    [microsoft.win32.registry]::SetValue($registryPath, $name, $User)

    $path = "HKLM:\Software\Google\GCPW\Users\" + $currentSid
    $userCheck = Get-ItemPropertyValue $path -Name $name

    if ($userCheck -eq $User) {
        # $msgResult = [System.Windows.MessageBox]::Show('Configuration completed successfully!', 'GCPW', 'OK', 'Info')
        Write-Output 'User configuration completed successfully!'
    }
    else {
        # $msgResult = [System.Windows.MessageBox]::Show('Could not write to registry. Configuration was not completed.', 'GCPW', 'OK', 'Error')
        Write-Output "Could not write User to registry. Configuration was not completed. (User -> $User)"
    }
}