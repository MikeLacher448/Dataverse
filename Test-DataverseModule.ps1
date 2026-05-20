# Dataverse Module Test Script
# This script provides basic tests to verify the module functionality

Write-Host "Dataverse Module Test Script" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

# Test 1: Import Module
Write-Host "`n1. Testing Module Import..." -ForegroundColor Yellow
try {
    Import-Module $PSScriptRoot\Dataverse.psd1 -Force
    Write-Host "   ✓ Module imported successfully" -ForegroundColor Green
    
    # Show module info
    $moduleInfo = Get-Module Dataverse
    Write-Host "   Module Version: $($moduleInfo.Version)" -ForegroundColor Cyan
    Write-Host "   Module Path: $($moduleInfo.ModuleBase)" -ForegroundColor Cyan
}
catch {
    Write-Host "   ✗ Failed to import module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Check Functions
Write-Host "`n2. Testing Function Availability..." -ForegroundColor Yellow
$expectedFunctions = @(
    'Connect-PSDVOrg',
    'Update-PSDVAccessToken',
    'Invoke-PSDVWebRequest',
    'Read-PSDVTableData',
    'Get-PSDVTableDetail',
    'Get-PSDVTableColumn',
    'Get-PSDVTableItem',
    'Get-PSDVTableItemAuditHistory',
    'Get-PSDVTableItemChangeHistory',
    'New-PSDVTableItem',
    'Update-PSDVTableItem',
    'Remove-PSDVTableItem'
)

$availableFunctions = Get-Command -Module Dataverse | Select-Object -ExpandProperty Name
$missingFunctions = $expectedFunctions | Where-Object { $_ -notin $availableFunctions }

if ($missingFunctions.Count -eq 0) {
    Write-Host "   ✓ All expected functions are available ($($expectedFunctions.Count) functions)" -ForegroundColor Green
}
else {
    Write-Host "   ✗ Missing functions: $($missingFunctions -join ', ')" -ForegroundColor Red
}

$connectCommand = Get-Command Connect-PSDVOrg
if ($connectCommand.Parameters.ContainsKey('ManagedIdentityTokenSource')) {
    Write-Host "   ✓ ManagedIdentityTokenSource parameter is available" -ForegroundColor Green

    $validateSet = $connectCommand.Parameters['ManagedIdentityTokenSource'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
    $expectedTokenSources = @('AzureIdentity', 'FunctionRuntime')
    $missingTokenSources = $expectedTokenSources | Where-Object { $_ -notin $validateSet.ValidValues }
    if ($missingTokenSources.Count -eq 0) {
        Write-Host "   ✓ ManagedIdentityTokenSource validates AzureIdentity and FunctionRuntime" -ForegroundColor Green
    }
    else {
        Write-Host "   ✗ ManagedIdentityTokenSource missing values: $($missingTokenSources -join ', ')" -ForegroundColor Red
    }
}
else {
    Write-Host "   ✗ ManagedIdentityTokenSource parameter is missing" -ForegroundColor Red
}

# Test 3: Check Help Documentation
Write-Host "`n3. Testing Help Documentation..." -ForegroundColor Yellow
$functionsWithoutHelp = @()
foreach ($function in $expectedFunctions) {
    $help = Get-Help $function -ErrorAction SilentlyContinue
    if (-not $help -or $help.Synopsis -like "*$function*") {
        $functionsWithoutHelp += $function
    }
}

if ($functionsWithoutHelp.Count -eq 0) {
    Write-Host "   ✓ All functions have proper help documentation" -ForegroundColor Green
}
else {
    Write-Host "   ✗ Functions missing help: $($functionsWithoutHelp -join ', ')" -ForegroundColor Red
}

# Test 4: Check Aliases
Write-Host "`n4. Testing Aliases..." -ForegroundColor Yellow
$aliases = Get-Alias | Where-Object { $_.Definition -eq 'Remove-PSDVTableItem' }
if ($aliases) {
    Write-Host "   ✓ Backward compatibility alias found: $($aliases.Name)" -ForegroundColor Green
}
else {
    Write-Host "   ⚠ No backward compatibility aliases found" -ForegroundColor Yellow
}

# Test 5: Basic Parameter Validation
Write-Host "`n5. Testing Parameter Validation..." -ForegroundColor Yellow
try {
    # This should fail with proper error about missing connection
    Get-PSDVTableItem -Table "account" -ErrorAction Stop
    Write-Host "   ✗ Function should have failed without connection" -ForegroundColor Red
}
catch {
    if ($_.Exception.Message -like "*No existing connection*") {
        Write-Host "   ✓ Proper connection validation working" -ForegroundColor Green
    }
    else {
        Write-Host "   ⚠ Unexpected error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$tableParameterBindingCases = @(
    @{ Name = 'Get-PSDVTableColumn -Table'; Command = { Get-PSDVTableColumn -Table 'account' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableDetail -Table'; Command = { Get-PSDVTableDetail -Table 'account' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItem -Table'; Command = { Get-PSDVTableItem -Table 'account' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItem -EntitySet'; Command = { Get-PSDVTableItem -EntitySet 'accounts' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItem -Table -ItemID'; Command = { Get-PSDVTableItem -Table 'account' -ItemID '00000000-0000-0000-0000-000000000001' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItem -EntitySet -ItemID'; Command = { Get-PSDVTableItem -EntitySet 'accounts' -ItemID '00000000-0000-0000-0000-000000000001' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItem legacy item lookup aliases'; Command = { Get-PSDVTableItem -Table 'account' -ItemID '00000000-0000-0000-0000-000000000001' -SelectFields 'name' -ExpandQuery 'primarycontactid' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItem legacy query aliases'; Command = { Get-PSDVTableItem -Table 'account' -FilterQuery "name eq 'Contoso'" -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItemAuditHistory -Table -ItemID'; Command = { Get-PSDVTableItemAuditHistory -Table 'account' -ItemID '00000000-0000-0000-0000-000000000001' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItemChangeHistory -Table -ItemID'; Command = { Get-PSDVTableItemChangeHistory -Table 'account' -ItemID '00000000-0000-0000-0000-000000000001' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableItemChangeHistory -EntitySet -ItemID'; Command = { Get-PSDVTableItemChangeHistory -EntitySet 'accounts' -ItemID '00000000-0000-0000-0000-000000000001' -ErrorAction Stop } },
    @{ Name = 'Get-PSDVTableWebHook -Table'; Command = { Get-PSDVTableWebHook -Table 'account' -ErrorAction Stop } }
)

$parameterBindingFailures = @()
foreach ($case in $tableParameterBindingCases) {
    try {
        & $case.Command
        $parameterBindingFailures += $case.Name
    }
    catch {
        if ($_.Exception.Message -notlike '*No existing connection*') {
            $parameterBindingFailures += "$($case.Name): $($_.Exception.Message)"
        }
    }
}

if ($parameterBindingFailures.Count -eq 0) {
    Write-Host "   ✓ Get-PSDVTable* minimum parameter combinations bind without ambiguity" -ForegroundColor Green
}
else {
    Write-Host "   ✗ Get-PSDVTable* parameter binding failures:" -ForegroundColor Red
    $parameterBindingFailures | ForEach-Object { Write-Host "     - $_" -ForegroundColor Red }
}

# Test 6: Check Bundled Azure.Identity SDK
Write-Host "`n6. Testing Bundled Azure.Identity SDK..." -ForegroundColor Yellow
$moduleInfo = Get-Module Dataverse
$azureIdentityDll = Join-Path $moduleInfo.ModuleBase 'lib\netstandard2.0\Azure.Identity.dll'
if (Test-Path -Path $azureIdentityDll -PathType Leaf) {
    Write-Host "   ✓ Bundled Azure.Identity SDK found" -ForegroundColor Green

    try {
        & $moduleInfo { Import-PSDVAzureIdentityAssemblies }
        $azureIdentityType = 'Azure.Identity.InteractiveBrowserCredential' -as [type]
        if ($null -ne $azureIdentityType) {
            Write-Host "   ✓ Azure.Identity SDK loads successfully" -ForegroundColor Green
        }
        else {
            Write-Host "   ✗ Azure.Identity SDK did not register expected types" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "   ✗ Azure.Identity SDK failed to load: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "   ✗ Bundled Azure.Identity SDK missing: $azureIdentityDll" -ForegroundColor Red
}

# Test 7: Show Module Summary
Write-Host "`n7. Module Summary..." -ForegroundColor Yellow
$moduleInfo = Get-Module Dataverse
Write-Host "   Module Name: $($moduleInfo.Name)" -ForegroundColor Cyan
Write-Host "   Version: $($moduleInfo.Version)" -ForegroundColor Cyan
Write-Host "   Author: $($moduleInfo.Author)" -ForegroundColor Cyan
Write-Host "   Description: $($moduleInfo.Description)" -ForegroundColor Cyan
Write-Host "   Exported Functions: $($moduleInfo.ExportedFunctions.Count)" -ForegroundColor Cyan
Write-Host "   Required Modules: $($moduleInfo.RequiredModules.Name -join ', ')" -ForegroundColor Cyan

Write-Host "`n==============================" -ForegroundColor Green
Write-Host "Module testing completed!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Use Connect-PSDVOrg to establish a connection" -ForegroundColor White
Write-Host "2. Start using the module functions" -ForegroundColor White
Write-Host "`nFor detailed help on any function, use:" -ForegroundColor Yellow
Write-Host "   Get-Help <FunctionName> -Full" -ForegroundColor Gray
