function Set-PsApimProduct {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject[]] $Product,

        [Parameter(Mandatory = $true)]
        [PsfValidateScript('PSFramework.Validate.FSPath.Folder', ErrorString = 'PSFramework.Validate.FSPath.Folder')]
        [string] $Path,

        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext,

        [switch] $PassThru
    )
    
    begin {
        $propsToExclude = @("ProductPolicyFile")
    }
    
    process {
        foreach ($productItem in $Product) {
            $parms = ConvertTo-PSFHashtable -InputObject $productItem -Exclude $propsToExclude
            
            Write-PSFMessage -Level Verbose -Message "Setting the Product: $($productItem.ProductId)."
            $res = New-AzApiManagementProduct -Context $ApimContext @parms
            
            if ($PassThru) { $res }
            
            if ($productItem.ProductPolicyFile) {
                Write-PSFMessage -Level Verbose -Message "There is policy defined for the Product: $($productItem.ProductId)."

                $filePath = Join-PSFPath -Path $Path -Child "product.policies", $productItem.ProductPolicyFile

                if (-not (Test-PathExists -Path $filePath -Type Leaf)) {
                    return
                }

                if (Test-PSFFunctionInterrupt) { return }

                $policyString = Get-Content -Path $filePath -Raw
                
                Write-PSFMessage -Level Verbose -Message "Setting the policy defined for the Product: $($productItem.ProductId)."
                $res = Set-AzApiManagementPolicy -Context $ApimContext -ProductId $productItem.ProductId -Policy $policyString
                
                if ($PassThru) { $res }
            }
        }
    }
    
    end {
        if (Test-PSFFunctionInterrupt) { return }
        
    }
}