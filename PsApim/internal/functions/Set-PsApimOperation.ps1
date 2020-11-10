<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER ApiId
Parameter description

.PARAMETER Path
Parameter description

.PARAMETER Operation
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
function Set-PsApimOperation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ApiId,

        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PsCustomObject[]] $Operation,

        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext,

        [switch] $PassThru
    )
    
    begin {
        $propsToExclude = @("TemplateParameters", "Responses", "Request", "OperationPolicyFile")
    }
    
    process {
        foreach ($operationItem in $Operation) {
            $parms = ConvertTo-PSFHashtable -InputObject $operationItem -Exclude $propsToExclude

            Write-PSFMessage -Level Verbose -Message "Setting the Operation: $($operationItem.OperationId)."

            if ($null -ne $operationItem.TemplateParameters -and $operationItem.TemplateParameters.Count -gt 0) {
                # Todo: Needs to be implemented
            }

            if ($operationItem.Responses) {
                $responses = foreach ($responseItem in $operationItem.Responses) {
                    $response = [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementResponse]::new()
    
                    foreach ($responseProp in $responseItem.PsObject.Properties) {
                        $response."$($responseProp.Name)" = $responseProp.Value
                    }

                    $response
                }

                $parms.Responses = @($responses)
            }
         
            if ($operationItem.Request) {
                $request = [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementRequest]::new()
                
                foreach ($requestProp in $($operationItem.Request.PsObject.Properties)) {
                    if ($requestProp.Name -ne "Representations") {
                        $request."$($requestProp.Name)" = $requestProp.Value
                    }
                }
    
                if ($operationItem.Request.Representations) {
                    $representations = foreach ($representationItem in $operationItem.Request.Representations) {
                        $representation = [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementRepresentation]::new()
    
                        foreach ($representationProp in $representationItem.PsObject.Properties) {
                            $representation."$($representationProp.Name)" = $representationProp.Value
                        }

                        $representation
                    }

                    $request.Representations = @($representations)
                }

                $parms.Request = $request
            }
 
            $res = New-AzApiManagementOperation -Context $ApimContext @parms -ApiId $ApiId
            
            if (-not $res) {
                $messageString = "Unable to deploy the Operation: <c='em'>$($operationItem.OperationId)</c>."
                Write-PSFMessage -Level Host -Message $messageString -Target $operationItem.OperationId
                Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                return
            }

            if ($PassThru) { $res }
            
            if ($operationItem.OperationPolicyFile) {
                Write-PSFMessage -Level Verbose -Message "There is a policy defined for the Operation: $($operationItem.OperationId)."
                
                $filePath = Join-PSFPath -Path $Path -Child "operation.policies", $operationItem.OperationPolicyFile

                Test-PathExists -Path $filePath -Type Leaf > $null

                if (Test-PSFFunctionInterrupt) {
                    Stop-PSFFunction -Message "The path for Operation policy file didn't exists." -StepsUpward 1
                    return
                }

                $policyString = Get-Content -Path $filePath -Raw
                
                Write-PSFMessage -Level Verbose -Message "Setting the policy defined for the Operation: $($operationItem.OperationId)."
                Set-AzApiManagementPolicy -Context $ApimContext -ApiId $ApiId -OperationId $parms.OperationId -Policy $policyString -ErrorVariable errorVar

                if ($errorVar) {
                    $messageString = "Unable to deploy the policy for the Operation: <c='em'>$($operationItem.OperationId)</c>."
                    Write-PSFMessage -Level Host -Message $messageString -Target $errorVar
                    Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                    return
                }

                if ($PassThru) { $policyString }
            }
        }
    }

    end {
        
    }
}