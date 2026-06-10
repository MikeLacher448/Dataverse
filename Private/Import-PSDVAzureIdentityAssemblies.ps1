function Import-PSDVAzureIdentityAssemblies {
    [CmdletBinding()]
    param()

    if ($script:PSDVAzureIdentityLoaded) {
        return
    }

    if (-not (Test-Path -Path $script:PSDVAzureIdentityAssemblyPath -PathType Container)) {
        throw "Azure.Identity bundled assemblies were not found at '$script:PSDVAzureIdentityAssemblyPath'"
    }

    $assemblyNames = @(
        'System.Buffers',
        'System.Numerics.Vectors',
        'System.Runtime.CompilerServices.Unsafe',
        'System.Memory',
        'System.Threading.Tasks.Extensions',
        'Microsoft.Bcl.AsyncInterfaces',
        'System.Diagnostics.DiagnosticSource',
        'System.Text.Encodings.Web',
        'System.Text.Json',
        'System.Memory.Data',
        'System.Security.Principal.Windows',
        'System.Security.AccessControl',
        'System.Security.Cryptography.ProtectedData',
        'System.IO.FileSystem.AccessControl',
        'System.ClientModel',
        'Azure.Core',
        'Microsoft.IdentityModel.Abstractions',
        'Microsoft.Identity.Client',
        'Microsoft.Identity.Client.Extensions.Msal',
        'Azure.Identity'
    )

    $identityClosureNames = @(
        'Azure.Core',
        'Azure.Identity',
        'Microsoft.Identity.Client',
        'Microsoft.Identity.Client.Extensions.Msal',
        'Microsoft.IdentityModel.Abstractions',
        'System.ClientModel'
    )

    $preferredAssemblyPath = $script:PSDVAzureIdentityAssemblyPath
    $loadedAzureIdentity = [AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'Azure.Identity' -and -not [string]::IsNullOrWhiteSpace($_.Location) } |
        Select-Object -First 1

    if ($loadedAzureIdentity) {
        $loadedAzureIdentityPath = (Resolve-Path -LiteralPath $loadedAzureIdentity.Location -ErrorAction Stop).Path
        $loadedAzureIdentityDirectory = Split-Path -Path $loadedAzureIdentityPath -Parent
        if (Test-Path -Path (Join-Path $loadedAzureIdentityDirectory 'Azure.Identity.dll') -PathType Leaf) {
            $preferredAssemblyPath = $loadedAzureIdentityDirectory
        }
    }

    foreach ($assemblyName in $assemblyNames) {
        $preferredAssemblyFile = Join-Path $preferredAssemblyPath "$assemblyName.dll"
        $bundledAssemblyFile = Join-Path $script:PSDVAzureIdentityAssemblyPath "$assemblyName.dll"
        $assemblyPath = if (Test-Path -Path $preferredAssemblyFile -PathType Leaf) { $preferredAssemblyFile } else { $bundledAssemblyFile }

        if (-not (Test-Path -Path $assemblyPath -PathType Leaf)) {
            continue
        }

        $resolvedAssemblyPath = (Resolve-Path -LiteralPath $assemblyPath -ErrorAction Stop).Path
        $loadedAssemblies = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GetName().Name -eq $assemblyName -and -not [string]::IsNullOrWhiteSpace($_.Location) }

        if ($assemblyName -in $identityClosureNames) {
            $conflictingAssembly = $loadedAssemblies |
                Where-Object { (Resolve-Path -LiteralPath $_.Location -ErrorAction Stop).Path -ne $resolvedAssemblyPath } |
                Select-Object -First 1

            if ($conflictingAssembly) {
                throw "Azure.Identity dependency '$assemblyName' is already loaded from '$($conflictingAssembly.Location)', but this session requires '$resolvedAssemblyPath'. Start a new PowerShell session so the Azure.Identity dependency set can load consistently."
            }
        }

        Add-Type -Path $resolvedAssemblyPath -ErrorAction Stop
    }

    if ($null -eq ('Azure.Identity.InteractiveBrowserCredential' -as [type])) {
        $loadedAzureIdentity = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GetName().Name -eq 'Azure.Identity' } |
            Select-Object -First 1

        if ($loadedAzureIdentity) {
            throw "Azure.Identity loaded from '$($loadedAzureIdentity.Location)' but PowerShell could not resolve Azure.Identity types. Start a new PowerShell session and import this module before loading other Azure modules."
        }

        throw 'Azure.Identity failed to load from the bundled module assemblies'
    }

    $script:PSDVAzureIdentityLoaded = $true
}

