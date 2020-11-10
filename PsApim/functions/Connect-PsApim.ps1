<#
.SYNOPSIS
Connect to Azure API Management instance

.DESCRIPTION
Make sure that your current PowerShell session is connected to the desired Azure API Management instance

.PARAMETER ResourceGroup
Name of Resource Group where the Azure API Management instance is located

.PARAMETER ApimInstance
Name of the Azure API Management instance

.PARAMETER ApimContext
Context object for the desired Azure API Management instance

Use it if you have it at hand when running the different functions, and to avoid using the Connect-PsApim between module loads

.PARAMETER PushToGlobalScope
Instruct the function to push the default ApimContext object into the global variable (user) session, to have the object survive module loads

.EXAMPLE
PS C:\> Connect-PsApim -ResourceGroup "rg-test" -ApimInstance "api-test-001"

This will connect to the APIM instance called "api-test-001", which is located in the "rg-test" resource group.

.EXAMPLE
PS C:\> Connect-PsApim -ResourceGroup "rg-test" -ApimInstance "api-test-001" -PushToGlobalScope

This will connect to the APIM instance called "api-test-001", which is located in the "rg-test" resource group.
The ApimContext will be pushed into the $Global:PSDefaultParameterValues object.

.NOTES
The entire module requires that you already have an connection / session using the Connect-AzAccount, and set the AzContext to point to the appropriate subscription.

PS C:\> Connect-AzAccount -Subscription $subscriptionId
PS C:\> Set-AzContext -Subscription $subscriptionId
PS C:\> Connect-PsApim -ResourceGroup "rg-test" -ApimInstance "api-test-001"

Author: Mötz Jensen (@Splaxi)

#>
function Connect-PsApim {
    [CmdletBinding(DefaultParameterSetName = "Default")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [string] $ResourceGroup,
        
        [Parameter(Mandatory = $true, ParameterSetName = "Default")]
        [Alias('ServiceName')]
        [string] $ApimInstance,

        [Parameter(Mandatory = $true, ParameterSetName = "Override")]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext,

        [switch] $PushToGlobalScope
    )
    
    begin {
        if ($PSCmdlet.ParameterSetName -eq "Default") {

            $res = Get-AzContext -ErrorAction SilentlyContinue

            if (-not $res) {
                $messageString = "Unable to find an active AzContext."
                Write-PSFMessage -Level Host -Message $messageString
                Stop-PSFFunction -Message "The AzContext wasn't found. Please make sure that you have signed into the correct subscription." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            $res = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue

            if (-not $res) {
                $messageString = "Unable to find the specified resource group: <c='em'>$ResourceGroup</c>."
                Write-PSFMessage -Level Host -Message $messageString
                Stop-PSFFunction -Message "The resource group wasn't found. Please check that the name is correct and that you have signed into the correct subscription." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            $res = Get-AzResource -Name $ApimInstance -ErrorAction SilentlyContinue

            if (-not $res) {
                $messageString = "Unable to find the specified APIM instance: <c='em'>$ApimInstance</c> inside the resource group: <c='em'>$ResourceGroup</c>."
                Write-PSFMessage -Level Host -Message $messageString
                Stop-PSFFunction -Message "The APIM instance wasn't found in the resource group. Please check that the name is correct, that you have signed into the correct subscription and the name of the resource group is correct." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
                return
            }

            $ApimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroup -ServiceName $ApimInstance
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) {
            $Script:PSDefaultParameterValues['*PsApi*:ApimContext'] = $null
            $Script:PSDefaultParameterValues['*PsApi*:SubscriptionId'] = $null
            return
        }

        Write-PSFMessage -Level Verbose -Message "Setting the default parameter for ApimContext across the module."

        $Script:PSDefaultParameterValues['*PsApi*:ApimContext'] = $ApimContext
        $Script:PSDefaultParameterValues['*PsApi*:SubscriptionId'] = (Get-AzContext).Subscription.Id
            
        if ($PushToGlobalScope) {
            $Global:PSDefaultParameterValues['*PsApi*:ApimContext'] = $ApimContext
            $Global:PSDefaultParameterValues['*PsApi*:SubscriptionId'] = (Get-AzContext).Subscription.Id
        }
    }
    
    end {
        
    }
}