# Vraag om de Active Directory OU die moet worden gescand
$ou = Read-Host "Geef de DistinguishedName van de Active Directory OU op (bijv. 'OU=Computers,DC=domain,DC=com'):"

# Verbinding maken met Active Directory
$domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
$root = $domain.GetDirectoryEntry()

# LDAP-filter om computers in de opgegeven OU te selecteren
$filter = "(&(objectClass=computer)(objectCategory=computer)(distinguishedName=$ou))"

# Zoek computers in de opgegeven OU
$searcher = New-Object System.DirectoryServices.DirectorySearcher($root, $filter)
$searcher.PageSize = 1000
$searcher.SearchScope = "Subtree"
$result = $searcher.FindAll()

# Lijst om resultaten op te slaan
$results = @()

# Loop door de gevonden computers
foreach ($entry in $result) {
    $computer = $entry.GetDirectoryEntry()
    $computerName = $computer.Name

    # Verbinding maken met de computer
    $server = "\\$computerName"
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $server)

    # Controleren of TLS 1.0, 1.1 of 1.2 zijn ingeschakeld
    $tls10Enabled = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client", $false) -ne $null
    $tls11Enabled = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client", $false) -ne $null
    $tls12Enabled = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client", $false) -ne $null

    # Resultaat toevoegen aan de lijst
    $resultObject = [PSCustomObject]@{
        ComputerName = $computerName
        TLS1_0Enabled = $tls10Enabled
        TLS1_1Enabled = $tls11Enabled
        TLS1_2Enabled = $tls12Enabled
    }
    $results += $resultObject
}

# Exporteer resultaten naar CSV
$results | Export-Csv -Path "TLS_Report.csv" -NoTypeInformation
