function Connect-PSDVOrg {
    <#
    .SYNOPSIS
    Establishes a connection to a Microsoft Dataverse organization.

    .DESCRIPTION
    Connect-PSDVOrg creates an authenticated connection to a Microsoft Dataverse environment using various authentication methods.
    It supports service principal authentication with client secrets or certificates, managed identity authentication, and interactive browser login.
    Upon successful connection, it retrieves and stores an access token for subsequent Dataverse API calls.

    .PARAMETER ClientID
    The Application (client) ID of the Azure AD application registration used for service principal authentication.

    .PARAMETER ClientSecret
    The client secret (secure string) for the Azure AD application used for service principal authentication.

    .PARAMETER Certificate
    The X.509 certificate with private key used for service principal authentication.

    .PARAMETER CertificateThumbprint
    The thumbprint of a certificate with private key in the CurrentUser or LocalMachine personal certificate store.

    .PARAMETER CertificatePath
    The path to a PFX certificate file used for service principal authentication.

    .PARAMETER CertificatePassword
    The optional PFX certificate password.

    .PARAMETER ManagedIdentityID
    The client ID, object ID, or Azure resource ID of the managed identity to use for authentication in Azure environments (user-assigned managed identity). FunctionRuntime token acquisition supports client ID or Azure resource ID.

    .PARAMETER UseSystemManagedIdentity
    When specified, uses the system-assigned managed identity for authentication. No additional identity configuration is required.

    .PARAMETER AzureTenantId
    The Microsoft Entra tenant ID where the Dataverse environment is located. Required for client secret and interactive authentication.

    .PARAMETER SubscriptionId
    Optional legacy parameter retained for compatibility with older examples. It is no longer used because this module no longer connects an Azure subscription context.

    .PARAMETER DataverseOrgURL
    The URL of the Dataverse organization (e.g., https://orgname.crm.dynamics.com/).

    .PARAMETER Environment
    The Azure cloud authority host to use for OAuth token acquisition. Defaults to AzureCloud.

    .PARAMETER UseDeviceCode
    Uses device code authentication instead of the default browser-based interactive authentication.

    .PARAMETER ManagedIdentityTokenSource
    Controls how managed identity tokens are acquired. AzureIdentity uses the bundled Azure.Identity SDK. FunctionRuntime calls the Azure Functions/App Service managed identity endpoint directly without loading Azure.Identity.

    .EXAMPLE
    Connect-PSDVOrg -AzureTenantId "12345678-1234-1234-1234-123456789012" -DataverseOrgURL "https://contoso.crm.dynamics.com/"

    Connects to Dataverse using interactive authentication.

    .EXAMPLE
    $secret = ConvertTo-SecureString "MyClientSecret" -AsPlainText -Force
    Connect-PSDVOrg -ClientID "12345678-1234-1234-1234-123456789012" -ClientSecret $secret -AzureTenantId "87654321-4321-4321-4321-210987654321" -DataverseOrgURL "https://contoso.crm.dynamics.com/" -Environment "AzureCloud"

    Connects to Dataverse using service principal authentication.

    .EXAMPLE
    Connect-PSDVOrg -ClientID "12345678-1234-1234-1234-123456789012" -CertificateThumbprint "ABCDEF1234567890ABCDEF1234567890ABCDEF12" -AzureTenantId "87654321-4321-4321-4321-210987654321" -DataverseOrgURL "https://contoso.crm.dynamics.com/"

    Connects to Dataverse using service principal certificate authentication.

    .EXAMPLE
    Connect-PSDVOrg -ManagedIdentityID "12345678-1234-1234-1234-123456789012" -DataverseOrgURL "https://contoso.crm.dynamics.com/"

    Connects to Dataverse using user-assigned managed identity authentication.

    .EXAMPLE
    Connect-PSDVOrg -UseSystemManagedIdentity -DataverseOrgURL "https://contoso.crm.dynamics.com/"

    Connects to Dataverse using system-assigned managed identity authentication.

    .EXAMPLE
    Connect-PSDVOrg -UseSystemManagedIdentity -ManagedIdentityTokenSource FunctionRuntime -DataverseOrgURL "https://contoso.crm.dynamics.com/"

    Connects to Dataverse using the Azure Functions/App Service managed identity endpoint directly without loading Azure.Identity.
    #>

    [CmdletBinding(DefaultParameterSetName = 'InteractiveLogin')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCertificate')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCertificateThumbprint')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCertificatePath')]
        [String]
        $ClientID,

        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [SecureString]
        $ClientSecret,

        [Parameter(Mandatory, ParameterSetName = 'ClientCertificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate,

        [Parameter(Mandatory, ParameterSetName = 'ClientCertificateThumbprint')]
        [String]
        $CertificateThumbprint,

        [Parameter(Mandatory, ParameterSetName = 'ClientCertificatePath')]
        [String]
        $CertificatePath,

        [Parameter(ParameterSetName = 'ClientCertificatePath')]
        [SecureString]
        $CertificatePassword,

        [Parameter(Mandatory, ParameterSetName = 'ManagedIdentity')]
        [String]
        $ManagedIdentityID,

        [Parameter(Mandatory, ParameterSetName = 'SystemManagedIdentity')]
        [Switch]
        $UseSystemManagedIdentity,

        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCertificate')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCertificateThumbprint')]
        [Parameter(Mandatory, ParameterSetName = 'ClientCertificatePath')]
        [Parameter(Mandatory, ParameterSetName = 'InteractiveLogin')]
        [String]
        $AzureTenantId,

        [Parameter(ParameterSetName = 'InteractiveLogin')]
        [String]
        $SubscriptionId,

        [Parameter(Mandatory)]
        [String]
        $DataverseOrgURL,

        [Parameter()]
        [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment', 'AzureGermanCloud')]
        [String]
        $Environment = 'AzureCloud',

        [Parameter(ParameterSetName = 'InteractiveLogin')]
        [Switch]
        $UseDeviceCode,

        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [Parameter(ParameterSetName = 'SystemManagedIdentity')]
        [ValidateSet('AzureIdentity', 'FunctionRuntime')]
        [String]
        $ManagedIdentityTokenSource = 'AzureIdentity'
    )

    #Ensure DataverseOrgURL has a trailing slash
    if (-not $DataverseOrgURL.EndsWith('/')) {
        $DataverseOrgURL = $DataverseOrgURL + '/'
    }

    $authContext = @{
        ParameterSetName  = $PSCmdlet.ParameterSetName
        ResourceUrl       = $DataverseOrgURL
        ClientID          = $ClientID
        ClientSecret      = $ClientSecret
        Certificate       = $Certificate
        CertificateThumbprint = $CertificateThumbprint
        CertificatePath   = $CertificatePath
        CertificatePassword = $CertificatePassword
        AzureTenantId     = $AzureTenantId
        ManagedIdentityID = $ManagedIdentityID
        Environment       = $Environment
        SubscriptionId    = $SubscriptionId
        UseDeviceCode     = $UseDeviceCode.IsPresent
        ManagedIdentityTokenSource = $ManagedIdentityTokenSource
    }
    
    try {
        Write-Verbose "Getting Dataverse Access Token for $DataverseOrgUrl"
        $accessToken = Get-PSDVAccessToken -AuthContext $authContext
        if ($accessToken.PSObject.Properties.Name -contains 'RefreshToken') {
            $authContext.RefreshToken = $accessToken.RefreshToken
        }

        $Global:DATAVERSEAUTHCONTEXT = $authContext
        $Global:DATAVERSEACCESSTOKEN = $accessToken
        $Global:DATAVERSEORGURL = $DataverseOrgURL
    }
    catch {
        throw "Error executing $($_.InvocationInfo.MyCommand.Name), $($_ | Out-String)"
    }

}

