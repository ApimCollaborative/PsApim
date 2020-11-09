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

        # foreach ($api in $apis) {
        #     if ($api.Name -NotLike $ApiId) { continue }
        #     $api
        #     $obj | Select-PSFObject -TypeName D365FO.TOOLS.Azure.Blob "name", @{Name = "Size"; Expression = { [PSFSize]$_.Properties.Length } }, "IsDeleted", @{Name = "LastModified"; Expression = { [Datetime]::Parse($_.Properties.LastModified) } }
        # }
    }
    
    end {
        
    }
}