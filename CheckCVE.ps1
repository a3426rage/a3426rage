# Check the OS version
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$osCaption = $osInfo.Caption
Write-Output "OS: $osCaption"

# Set the CVE ID
$CVEID = "CVE-2021-1234"

# Scrape KBs associated with the CVE from Microsoft Security Update Guide
$uri = "https://msrc.microsoft.com/update-guide/vulnerability/$CVEID"
$response = Invoke-WebRequest -Uri $uri
$htmlContent = $response.Content

# Extract KB article numbers and related OS information from the HTML content
$regex = '(?<=<tr>).*?(?=<\/tr>)'
$trMatches = [regex]::Matches($htmlContent, $regex)

$KBInfo = $trMatches | ForEach-Object {
    $content = $_.Value
    $kbRegex = 'KB\d+'
    $osRegex = '(?<=<td>).*?(?=<\/td>)'

    $kbMatch = [regex]::Match($content, $kbRegex)
    $osMatches = [regex]::Matches($content, $osRegex)

    if ($kbMatch.Success -and $osMatches.Count -gt 0) {
        @{
            "KBNumber" = $kbMatch.Value
            "OS"       = $osMatches[1].Value.Trim()
        }
    }
} | Where-Object { $_ -ne $null }

# Filter KBs based on the current operating system
$relevantKBs = $KBInfo | Where-Object { $_.OS -match $osCaption } | ForEach-Object { $_.KBNumber }

# Get the installed hotfixes on the server
$hotfixes = Get-HotFix

# Check if the relevant KBs are installed
$isInstalled = $false
foreach ($kb in $relevantKBs) {
    if ($hotfixes | Where-Object { $_.HotFixID -eq $kb }) {
        $isInstalled = $true
        break
    }
}

if ($isInstalled) {
    Write-Output "The server is not vulnerable to $CVEID"
} else {
    Write-Output "The server is vulnerable to $CVEID"
}
