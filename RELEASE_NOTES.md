# Dataverse PowerShell Module 1.1.0 Release Notes

Release date: 2026-06-10

Version 1.1.0 is a substantial update from the 1.0.0 release on `main`. It expands Dataverse operations, removes the direct Az.Accounts dependency, improves authentication flexibility, and adds automated test coverage for the module.

## Highlights

- Removed the direct Az.Accounts module dependency and bundled the Azure.Identity authentication dependencies with the module.
- Added browser-based interactive authentication support for MFA and Conditional Access scenarios.
- Added direct bearer token authentication through `Connect-PSDVOrg -AccessToken`, so users can acquire tokens with existing Azure tooling such as `Get-AzAccessToken` or Azure CLI and pass them to the module.
- Added managed identity support improvements, including system-assigned managed identity and an optional FunctionRuntime token source for Azure Functions/App Service environments.
- Added Dataverse webhook management commands.
- Added Pester test coverage for public and private module behavior.
- Refactored the module from a large monolithic script into focused `Public` and `Private` function files.

## Authentication Changes

- `Connect-PSDVOrg` now supports service principal authentication with client secrets and certificates, user-assigned managed identity, system-assigned managed identity, interactive browser login, device code login, and externally supplied bearer tokens.
- `-AccessToken` accepts a `SecureString` bearer token for the Dataverse resource.
- `-AccessTokenExpiresOn` can be provided with externally supplied tokens. If omitted, the module attempts to read the JWT `exp` claim.
- Supplied bearer tokens are not refreshed automatically. When a supplied token expires, acquire a new token and run `Connect-PSDVOrg` again.
- `Disconnect-PSDVOrg` clears the current session's Dataverse connection state.

## Dataverse API Improvements

- Added webhook cmdlets:
  - `New-PSDVTableWebHook`
  - `Get-PSDVTableWebHook`
  - `Remove-PSDVTableWebHook`
  - `Update-PSDVTableWebHookAuthSecret`
- Added `Get-PSDVTableItemAuditHistory` and `Get-PSDVTableItemChangeHistory` support.
- Added `-Top` OData query support to table item retrieval.
- Improved table column output to include available choice values.
- Hardened OData query construction and encoding for select, filter, expand, and paging scenarios.
- Improved pagination error handling and null/empty response behavior.
- Hardened webhook filter handling, GUID validation, and webhook secret escaping.

## Packaging And Compatibility

- Module version is now `1.1.0` in `Dataverse.psd1`.
- Minimum PowerShell version is `7.3`.
- Compatible PowerShell edition is `Core`.
- Azure.Identity and related dependencies are bundled under `lib/netstandard2.0`.
- The legacy `Install-DataverseModule.ps1` installation helper was removed in favor of native PowerShell module packaging.

## Deprecations

The following compatibility parameters remain available in 1.1.0 but are deprecated and planned for removal in the next major version:

- `Connect-PSDVOrg -SubscriptionId`
- `Get-PSDVTableItem -FilterQuery`
- `Get-PSDVTableItem -ExpandQuery`
- `Get-PSDVTableItem -SelectFields`

Use `-Filter`, `-Expand`, and `-Select` for new table item query code.

## Testing

Version 1.1.0 adds Pester coverage for authentication helpers, token handling, request construction, table operations, webhook operations, and connection cleanup. Before release, the suite was validated with:

```powershell
Invoke-Pester -Path .\tests -Output Normal
```

## Known Limitations

- Externally supplied bearer tokens cannot be refreshed by the module.
- JWT expiration parsing is best-effort. If a supplied token does not expose a parseable `exp` claim, pass `-AccessTokenExpiresOn` explicitly.
- Azure.Identity assembly versions can still conflict in long-lived PowerShell sessions that preload incompatible Azure SDK assemblies. Use `-AccessToken` when you need to rely on the host's already-installed Azure authentication tools.
