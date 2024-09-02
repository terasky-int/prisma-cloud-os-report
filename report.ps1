# 
# Invoke-RestMethod https://raw.githubusercontent.com/witchcraze/EOL-DataSet/master/OS/OS_AlpineLinux.json -OutFile OS_AlpineLinux.json
# Invoke-RestMethod https://raw.githubusercontent.com/witchcraze/EOL-DataSet/master/OS/OS_Debian.json -OutFile OS_Debian.json
# Invoke-RestMethod https://raw.githubusercontent.com/witchcraze/EOL-DataSet/master/OS/OS_RHEL.json -OutFile OS_RHEL.json
# Invoke-RestMethod https://raw.githubusercontent.com/witchcraze/EOL-DataSet/master/OS/OS_Ubuntu.json -OutFile OS_Ubuntu.json

# Prisma Cloud console URI
$console        = ""
$collections    = "" # Comma-separated Collections to search

# Service Account credentials (Read Oinly)
$Body = @{
    username    = ""
    password    = ""
}

# Timestamp for a filename
$timestamp = Get-Date -UFormat "%d-%m-%Y-%R" | ForEach-Object { $_ -replace ":", "-" }

# EOL Search Function
function Get-EOL {
    param (
        $version,
        $osDistro
    )
    if ($osDistro -eq "alpine" -or $osDistro -eq "debian" -or $osDistro -eq "redhat") {
        $version = $version.Substring(0,$version.LastIndexOf("."))
    }
    $os = @{
        alpine  = "OS_AlpineLinux.json"
        debian  = "OS_Debian.json"
        redhat  = "OS_RHEL.json"
        ubuntu  = "OS_Ubuntu.json"
    }

    if ($null -eq $os[$osDistro]) {
        return $false
    }

    $alpine = Get-Content -Raw $os[$osDistro] | ConvertFrom-Json
    $eol = $alpine.Product.Supports.EOLs | Where-Object Version -eq $version | Select-Object Date | Get-Date
    $now = Get-Date
    if ($eol -le $now) {
        $true
    } else {
        $false
    }
}

# API Authorize and recieve Bearer token
$Parameters = @{
    Method      = "POST"
    Uri         =  $console + "/api/v32.07/authenticate"
    Body        = ($Body | ConvertTo-Json) 
    ContentType = "application/json"
}
$token          = Invoke-RestMethod @Parameters

# Run a request
$Parameters = @{
    Method          =  "GET"
    Uri             =  $console + "/api/v32.07/images?collections=$collections"
    Authentication  = "Bearer"
    Token           = ($token.token | ConvertTo-SecureString -AsPlainText -Force)
    ContentType     = "application/json"
}
$reply              = Invoke-RestMethod @Parameters

foreach ($a in $reply) {
    if (Get-EOL -version $a.osDistroVersion -osDistro $a.osDistro) {
      $row = [PSCustomObject]@{
        ID              = $a.id
        registry        = $a.repoTag.registry
        repository      = $a.repoTag.repo
        tag             = $a.repoTag.tag
        distro          = $a.distro
        osDistro        = $a.osDistro
        osDistroVersion = $a.osDistroVersion
        osDistroRelease = $a.osDistroRelease
        cluster         = $a.clusters -join ', '
        namespace       = $a.namespaces -join ', '
       }
    $row | Export-Csv -Path images_$timestamp.csv -NoTypeInformation -Append
  }
}
