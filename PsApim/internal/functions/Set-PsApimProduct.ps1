<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Product
Parameter description

.PARAMETER Path
Parameter description

.PARAMETER ApimContext
Parameter description

.PARAMETER PassThru
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-PsApimProduct {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
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
            
            if (-not $res) {
                $messageString = "Unable to deploy the Product: <c='em'>$($productItem.ProductId)</c>."
                Write-PSFMessage -Level Host -Message $messageString -Target $productItem.ProductId
                Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                return
            }

            if ($PassThru) { $res }
            
            if ($productItem.ProductPolicyFile) {
                Write-PSFMessage -Level Verbose -Message "There is policy defined for the Product: $($productItem.ProductId)."

                $filePath = Join-PSFPath -Path $Path -Child "product.policies", $productItem.ProductPolicyFile

                Test-PathExists -Path $filePath -Type Leaf > $null

                if (Test-PSFFunctionInterrupt) {
                    Stop-PSFFunction -Message "The path for Product policy file didn't exists." -StepsUpward 1
                    return
                }

                $policyString = Get-Content -Path $filePath -Raw
                
                Write-PSFMessage -Level Verbose -Message "Setting the policy defined for the Product: $($productItem.ProductId)."
                Set-AzApiManagementPolicy -Context $ApimContext -ProductId $productItem.ProductId -Policy $policyString -ErrorVariable errorVar

                if ($errorVar) {
                    $messageString = "Unable to deploy the policy for the Product: <c='em'>$($productItem.ProductId)</c>."
                    Write-PSFMessage -Level Host -Message $messageString -Target $errorVar
                    Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                    return
                }

                if ($PassThru) { $policyString }
            }
        }
    }
    
    end {
        if (Test-PSFFunctionInterrupt) { return }
        
    }
}