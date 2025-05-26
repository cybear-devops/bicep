<#
.\Run-AzBicep.ps1 `
-RunBicepWhatIf true `
-RunBicepDeploy false `
-StackName "network"
#>

<#
.\Run-AzBicep.ps1 `
-RunBicepWhatIf false `
-RunBicepWhatIfDestroy true `
-RunBicepDestroy true `
-StackName "network"
#>

param (
    [string]$RunBicepWhatIf = "true",
    [string]$RunBicepDeploy = "false",
    [string]$RunBicepWhatIfDestroy = "false",
    [string]$RunBicepDestroy = "false",
    [bool]$DebugMode = $false,

    # [Parameter(Mandatory = $true)]
    # [string]$ManagementGroupId,

    [Parameter(Mandatory = $true)]
    [string]$StackName
)

try
{
    $ErrorActionPreference = 'Stop'
    $CurrentWorkingDirectory = (Get-Location).path

    # Enable debug mode if DebugMode is set to $true
    if ($DebugMode)
    {
        $DebugPreference = "Continue"
        $Env:BICEP_LOG = "DEBUG"
    }
    else
    {
        $DebugPreference = "SilentlyContinue"
        $Env:BICEP_LOG = "ERROR"
    }

    function Convert-ToBoolean($value)
    {
        $valueLower = $value.ToLower()
        if ($valueLower -eq "true")
        {
            return $true
        }
        elseif ($valueLower -eq "false")
        {
            return $false
        }
        else
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Invalid value - $value. Exiting."
            exit 1
        }
    }

    # Function to check if Bicep is installed
    function Test-BicepExists
    {
        try
        {
            $bicepPath = Get-Command bicep -ErrorAction Stop
            Write-Host "`e[32m[$( $MyInvocation.MyCommand.Name )] Success: Bicep found at: $( $bicepPath.Source )`e[0m"
        }
        catch
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Bicep is not installed or not in PATH. Exiting."
            exit 1
        }
    }

    function Get-StackDirectory
    {
        param (
            [string]$StackName,
            [string]$CurrentWorkingDirectory
        )

        # Scan the 'stacks' directory and create a mapping
        $folderMap = @{ }
        $StacksFolderName = "stacks" # This shouldn't really ever change
        $StacksFullPath = Join-Path -Path $CurrentWorkingDirectory -ChildPath $StacksFolderName
        Set-Location $StacksFullPath
        Get-ChildItem -Path $StacksFullPath -Directory | ForEach-Object {
            $folderNumber = $_.Name.Split('_')[0]
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: Folder number is $folderNumber"
            $folderName = $_.Name.Split('_')[1]
            $folderMap[$folderName.ToLower()] = $_.Name
        }

        $targetFolder = $folderMap[$StackName.ToLower()]
        $CalculatedPath = Join-Path -Path $StacksFullPath -ChildPath $targetFolder
        Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: targetFolder is $targetFolder"
        if ($null -ne $targetFolder)
        {
            # Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Stack directory found, changing to folder: $CalculatedPath" -ForegroundColor Green
            Write-Host "`e[32m[$( $MyInvocation.MyCommand.Name )] Success: Stack directory found, changing to folder: $CalculatedPath`e[0m"
            Set-Location $CalculatedPath
        }
        else
        {
            throw "[$( $MyInvocation.MyCommand.Name )] Error: Invalid folder selection"
            exit 1
        }
    }

    # Function to execute Bicep WhatIf
    function Invoke-BicepWhatIf
    {
        [CmdletBinding()]
        param (
            [string]$WorkingDirectory = $WorkingDirectory
        )

        Begin {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Begin: Initializing Bicep WhatIf in $WorkingDirectory"
        }

        Process {
            if ($RunBicepWhatIf)
            {
                Write-Host "`e[32m[$( $MyInvocation.MyCommand.Name )] Info: Running Bicep WhatIf in $WorkingDirectory`e[0m"
                try
                {
                    Set-Location -Path $WorkingDirectory
                    # Existing Bicep WhatIf
                    New-AzDeployment `
                        -WhatIf `
                        -Name $StackName `
                        -Location "uksouth" `
                        -TemplateFile "main.bicep" `
                        -TemplateParameterFile "main.bicepparam"

                    # New Deployment Stack WhatIf which isn't supported yet
                    # New-AzSubscriptionDeploymentStack `
                    #     -WhatIf `
                    #     -Name $StackName `
                    #     -Location "uksouth" `
                    #     -TemplateFile "main.bicep" `
                    #     -TemplateParameterFile "main.bicepparam" `
                    #     -ActionOnUnmanage "deleteResources" `
                    #     -DenySettingsMode "none" `
                    #     -Force
                }
                catch
                {
                    throw "[$( $MyInvocation.MyCommand.Name )] Error encountered during Bicep plan: $_"
                    exit 1
                }
            }
        }

        End {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] End: Completed Bicep WhatIf execution"
        }
    }

    # Function to execute Bicep deploy
    function Invoke-BicepDeploy
    {
        if ($RunBicepDeploy -eq $true)
        {
            try
            {
                Write-Host "`e[32m[$( $MyInvocation.MyCommand.Name )] Info: Running Bicep Deploy in $WorkingDirectory`e[0m"
                Set-Location -Path $WorkingDirectory
                New-AzSubscriptionDeploymentStack `
                    -Name $StackName `
                    -Location "uksouth" `
                    -TemplateFile "main.bicep" `
                    -TemplateParameterFile "main.bicepparam" `
                    -ActionOnUnmanage "deleteResources" `
                    -DenySettingsMode "none" `
                    -Force
            }
            catch
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: Bicep Deploy failed"
                return $false
            }
        }
    }

    # Function to execute Bicep WhatIf for destroy
    function Invoke-BicepWhatIfDestroy
    {
        [CmdletBinding()]
        param (
            [string]$WorkingDirectory = $WorkingDirectory
        )

        Begin {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] Begin: Preparing to execute Bicep WhatIf Destroy in $WorkingDirectory"
        }

        Process {
            if ($RunBicepWhatIfDestroy)
            {
                try
                {
                    Write-Host "`e[32m[$( $MyInvocation.MyCommand.Name )] Info: Running Bicep WhatIf Destroy in $WorkingDirectory`e[0m"
                    Set-Location -Path $WorkingDirectory
                    # Existing Bicep WhatIf
                    Remove-AzDeployment `
                    -WhatIf `
                    -Name $StackName
                    # New Deployment Stack WhatIf which isn't supported yet
                    # Remove-AzSubscriptionDeploymentStack `
                    #     -WhatIf `
                    #     -Name $StackName `
                    #     -ActionOnUnmanage "deleteResources" `
                    #     -Force
                }
                catch
                {
                    throw  "[$( $MyInvocation.MyCommand.Name )] Error encountered during Bicep WhatIf Destroy: $_"
                    exit 1
                }
            }
            else
            {
                throw  "[$( $MyInvocation.MyCommand.Name )] Error encountered during Bicep WhatIf Destroy or internal script error occured: $_"
                exit 1
            }
        }

        End {
            Write-Debug "[$( $MyInvocation.MyCommand.Name )] End: Completed Bicep WhatIf Destroy execution"
        }
    }

    # Function to execute Bicep destroy
    function Invoke-BicepDestroy
    {
        if ($RunBicepDestroy -eq $true)
        {
            try
            {
                Write-Host "`e[32m[$( $MyInvocation.MyCommand.Name )] Info: Running Bicep Destroy in $WorkingDirectory`e[0m"
                Set-Location -Path $WorkingDirectory
                Remove-AzSubscriptionDeploymentStack `
                    -Name $StackName `
                    -ActionOnUnmanage "deleteResources" `
                    -Force
            }
            catch
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: Bicep Destroy failed"
                return $false
            }
        }
    }

    # Convert string parameters to boolean
    $ConvertedRunBicepWhatIf = Convert-ToBoolean $RunBicepWhatIf
    $ConvertedRunBicepDeploy = Convert-ToBoolean $RunBicepDeploy
    $ConvertedRunBicepWhatIfDestroy = Convert-ToBoolean $RunBicepWhatIfDestroy
    $ConvertedRunBicepDestroy = Convert-ToBoolean $RunBicepDestroy

    # Diagnostic output
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunBicepWhatIf: $ConvertedRunBicepWhatIf"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunBicepDeploy: $ConvertedRunBicepDeploy"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunBicepWhatIfDestroy: $ConvertedRunBicepWhatIfDestroy"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: ConvertedRunBicepDestroy: $ConvertedRunBicepDestroy"
    Write-Debug "[$( $MyInvocation.MyCommand.Name )] Debug: DebugMode: $DebugMode"

    # Chicken and Egg checker
    if ($ConvertedRunBicepWhatIf -eq $true -and $ConvertedRunBicepWhatIfDestroy -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: Both bicep what-if and bicep what-if destroy cannot be true at the same time"
        exit 1
    }

    if ($ConvertedRunBicepDeploy -eq $true -and $ConvertedRunBicepDestroy -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: Both bicep deploy and bicep destroy cannot be true at the same time"
        exit 1
    }

    if ($ConvertedRunBicepWhatIf -eq $false -and $ConvertedRunBicepDeploy -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: You must run bicep what-if and bicep deploy together to use this script"
        exit 1
    }

    if ($ConvertedRunBicepWhatIfDestroy -eq $false -and $ConvertedRunBicepDestroy -eq $true)
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: You must run bicep what-if destroy and bicep destroy together to use this script"
        exit 1
    }

    try
    {
        # Initial Bicep setup
        Test-BicepExists

        Get-StackDirectory -StackName $StackName -CurrentWorkingDirectory $CurrentWorkingDirectory
        $WorkingDirectory = (Get-Location).Path

        # Conditional Bicep WhatIf
        if ($ConvertedRunBicepWhatIf) 
        {
            Invoke-BicepWhatIf -WorkingDirectory $WorkingDirectory
            $InvokeBicepWhatIfSuccessful = $?
        }

        # Conditional Bicep Deploy
        if ($ConvertedRunBicepDeploy -and $InvokeBicepWhatIfSuccessful) 
        {
            Invoke-BicepDeploy -WorkingDirectory $WorkingDirectory
            $InvokeBicepDeploySuccessful = $?
        
            if (-not $InvokeBicepDeploySuccessful) {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: An error occurred during Bicep deploy command"
                exit 1
            }
        }

        # Conditional Bicep Destroy WhatIf
        if ($ConvertedRunBicepWhatIfDestroy -and -not $ConvertedRunBicepWhatIf)
        {
            Invoke-BicepWhatIfDestroy -WorkingDirectory $WorkingDirectory
            $InvokeBicepWhatIfDestroySuccessful = $?
        }
        

        # Conditional Bicep Destroy
        if ($ConvertedRunBicepDestroy -and $InvokeBicepWhatIfDestroySuccessful)
        {
            Invoke-BicepDestroy
            $InvokeBicepDestroySuccessful = $?
        
            if (-not $InvokeBicepDestroySuccessful)
            {
                throw "[$( $MyInvocation.MyCommand.Name )] Error: An error occurred during Bicep destroy command"
                exit 1
            }
        }        
    }
    catch
    {
        throw "[$( $MyInvocation.MyCommand.Name )] Error: in script execution: $_"
        exit 1
    }

}
catch
{
    throw "[$( $MyInvocation.MyCommand.Name )] Error: An error has occured in the script:  $_"
    exit 1
}