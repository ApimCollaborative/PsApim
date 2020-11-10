<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER ApiId
Parameter description

.PARAMETER Name
Parameter description

.PARAMETER ApimContext
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Get-PsApimApi {
    [CmdletBinding()]
    param (
        [string] $ApiId = "*",

        [string] $Name = "*",

        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext = (Get-PsApimDefaultContext)
    )
    
    begin {
    }
    
    process {
        $apis = Get-AzApiManagementApi -Context $ApimContext
        $apis = $apis | Where-Object Name -like "$Name"
        $apis = $apis | Where-Object ApiId -like "$ApiId"

        $apis
    }
    
    end {
        
    }
}