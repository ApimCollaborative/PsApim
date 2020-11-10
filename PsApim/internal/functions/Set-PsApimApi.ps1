<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER Api
Parameter description

.PARAMETER Path
Parameter description

.PARAMETER ApimContext
Parameter description

.PARAMETER SubscriptionId
Parameter description

.PARAMETER PassThru
Parameter description

.EXAMPLE
An example

.NOTES
General notes
#>
function Set-PsApimApi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject] $Api,

        [Parameter(Mandatory = $true)]
        [PsfValidateScript('PSFramework.Validate.FSPath.Folder', ErrorString = 'PSFramework.Validate.FSPath.Folder')]
        [string] $Path,

        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext,

        [string] $SubscriptionId,

        [switch] $PassThru
    )
    
    begin {
        $propsToExclude = @("ApprovalRequired", "SchemaFile", "SchemaId", "ApiPolicyFile")
    }
    
    process {
        $clearServiceUrl = $false

        if (-not $Api.ServiceUrl) {
            Write-PSFMessage -Level Verbose -Message "ServiceUrl for the Api: $($Api.ApiId) is blank."

            #! Hack used to keep Service Url null if needed. Part1.
            $Api.ServiceUrl = "https://dummy.com"
            $clearServiceUrl = $true
        }

        $parms = ConvertTo-PSFHashtable -InputObject $Api -Exclude $propsToExclude

        Write-PSFMessage -Level Verbose -Message "Setting the Api: $($Api.ApiId)."
        $res = New-AzApiManagementApi -Context $ApimContext @parms

        if ($PassThru) { $res }

        if ($clearServiceUrl) {
            Write-PSFMessage -Level Verbose -Message "Setting ServiceUrl for the Api: $($Api.ApiId) to blank."

            #! Hack used to keep Service Url null if needed. Part2.
            $uri = "subscriptions/$SubscriptionId/resourceGroups/$($ApimContext.ResourceGroupName)/providers/Microsoft.ApiManagement/service/$($ApimContext.ServiceName)/apis/$($parms.ApiId)`?api-version=2019-12-01"
            $res = Invoke-AzRestMethod -Method GET -Path $uri
            
            if (-not $res -or $res.StatusCode -NotLike "2*") {
                $messageString = "Unable to get the specified API: <c='em'>$($Api.ApiId)</c> via the REST API."
                Write-PSFMessage -Level Host -Message $messageString
                Stop-PSFFunction -Message "The API wasn't found. Please make sure that you have spelled the ApiId correct and that you're connected to the correct APIM instance." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                return
            }

            $apiObject = $res.Content | ConvertFrom-Json
            $apiObject.PsObject.Properties.Remove("id")
            $apiObject.properties.serviceUrl = $null
            $apiJson = $apiObject | ConvertTo-Json -Depth 10
            
            $res = Invoke-AzRestMethod -Method PUT -Path $uri -Payload $apiJson

            if (-not $res -or $res.StatusCode -NotLike "2*") {
                $messageString = "Unable to clear the <c='em'>ServiceUrl</c> for the specified API: <c='em'>$ApiId</c>."
                Write-PSFMessage -Level Host -Message $messageString
                Stop-PSFFunction -Message "The API wasn't found. Please make sure that you have spelled the ApiId correct and that you're connected to the correct APIM instance." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                return
            }

            if ($PassThru) { $res.Content }
        }

        if ($api.ApiPolicyFile) {
            Write-PSFMessage -Level Verbose -Message "There is policy defined for the Api: $($Api.ApiId)."
            
            $filePath = Join-PSFPath -Path $Path -Child $api.ApiPolicyFile

            if (-not (Test-PathExists -Path $filePath -Type Leaf)) {
                return
            }

            if (Test-PSFFunctionInterrupt) { return }

            $policyString = Get-Content -Path $filePath -Raw

            Write-PSFMessage -Level Verbose -Message "Setting the policy defined for the Api: $($Api.ApiId)."
            Set-AzApiManagementPolicy -Context $ApimContext -ApiId $ApiId -Policy $policyString -ErrorVariable errorVar

            if ($errorVar) {
                $messageString = "Unable to deploy the policy for the Api: $($Api.ApiId)."
                Write-PSFMessage -Level Host -Message $messageString -Target $errorVar
                Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                return
            }

            if ($PassThru) { $policyString }
        }
    }
    
    end {
        
    }
}