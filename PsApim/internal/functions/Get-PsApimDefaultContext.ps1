function Get-PsApimDefaultContext {
    [CmdletBinding()]
    param (
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext
    )
    
    begin {
    }
    
    process {
        if (-not $ApimContext) {
            throw 'Invalid ApimContext'
        }

        $ApimContext
    }
    
    end {
        
    }
}