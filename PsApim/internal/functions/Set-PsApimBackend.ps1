function Set-PsApimBackend {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [PsCustomObject[]] $Backend,

        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext,

        [switch] $PassThru
    )
    
    begin {
        $propsToExclude = @("BackendNamedValueId", "BackendType", "FunctionAppKeyName", "Credential")
    }
    
    process {
        foreach ($backendItem in $Backend) {
            $parms = ConvertTo-PSFHashtable -InputObject $backendItem -Exclude $propsToExclude
            
            Write-PSFMessage -Level Verbose -Message "Setting the Backend: $($backendItem.BackendId)."
            switch ($backendItem.BackendType) {
                "LogicApp" {
                    Write-PSFMessage -Level Verbose -Message "The Backend: $($backendItem.BackendId) is a LogicApp."

                    # Todo: Should we make sure that the discovery phase doesn't include "https://management.azure.com/ ?"
                    $resourceId = $("$($backendItem.ResourceId)" -replace "https://management.azure.com/", "")

                    $uri = "$resourceId/triggers/manual/listCallbackUrl?api-version=2016-06-01"

                    Write-PSFMessage -Level Verbose -Message "Getting the LogicApp details."
                    $res = Invoke-AzRestMethod -Method POST -Path $uri

                    if (-not $res -or $res.StatusCode -NotLike "2*") {
                        $messageString = "Unable to get the details about the LogicApp: <c='em'>$resourceId</c>."
                        Write-PSFMessage -Level Host -Message $messageString -Target $resourceId
                        Stop-PSFFunction -Message "The http request against the LogicApp failed. Please make sure that your current PowerShell session is capable of reaching the LogicApp. Check if the LogicApp is stored in another subscription, resource group or location." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                        return
                    }
                    
                    $logicAppTrigger = $res.Content | ConvertFrom-Json

                    if (-Not ($logicAppTrigger.basePath -Match "(https://.+/triggers)")) {
                        $messageString = "Unable to get the Sig Query parameter from the LogicApp: <c='em'>$resourceId</c>."
                        Write-PSFMessage -Level Host -Message $messageString -Target $logicAppTrigger.basePath
                        Stop-PSFFunction -Message "The logic for locating the Sig value didn't find anything." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                        return
                    }
                    else {
                        $parms.Url = $Matches[0]
                    }
                  
                    #TODO: When a Logic App is using Authentication / Authorization - we should avoid the Sig value.
                    $parmsNamed = @{
                        NamedValueId = $backendItem.BackendNamedValueId
                        Name         = $backendItem.BackendNamedValueId
                        Value        = $logicAppTrigger.Queries.Sig
                        Secret       = $true
                    }
                            
                    $res = New-AzApiManagementNamedValue -Context $ApimContext @parmsNamed

                    if (-not $res) {
                        $messageString = "Unable to save the Named Value: <c='em'>$($backendItem.BackendNamedValueId)</c>."
                        Write-PSFMessage -Level Host -Message $messageString -Target $backendItem.BackendNamedValueId
                        Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                        return
                    }
        
                    if ($PassThru) { $res }
                }
                "FunctionApp" {
                    Write-PSFMessage -Level Verbose -Message "The Backend: $($backendItem.BackendId) is a FunctionApp / Azure Function."

                    # Todo: Should we make sure that the discovery phase doesn't include "https://management.azure.com/ ?"
                    $resourceId = $("$($backendItem.ResourceId)" -replace "https://management.azure.com/", "")

                    $uri = "$resourceId/host/default/listKeys?api-version=2018-11-01"

                    Write-PSFMessage -Level Verbose -Message "Getting the FunctionApp details."
                    $res = Invoke-AzRestMethod -Method POST -Path $uri
                    $keys = $res.Content | ConvertFrom-Json
                        
                    $parmsNamed = @{
                        NamedValueId = $backendItem.BackendNamedValueId
                        Name         = $backendItem.BackendNamedValueId
                        Value        = $($keys.functionKeys."$($backendItem.FunctionAppKeyName)")
                        Secret       = $true
                    }
                    
                    $res = New-AzApiManagementNamedValue -Context $ApimContext @parmsNamed

                    if (-not $res) {
                        $messageString = "Unable to save the Named Value: <c='em'>$($backendItem.BackendNamedValueId)</c>."
                        Write-PSFMessage -Level Host -Message $messageString -Target $backendItem.BackendNamedValueId
                        Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                        return
                    }
        
                    if ($PassThru) { $res }

                    #TODO: FunctionApp could be using custom domain name. Solve it by having a Url property in the api.json file.
                    #! If Url is NOT null, then use the URL property
                    if (-not $backendItem.url) {
                        $uri = "$resourceId`?api-version=2019-08-01"
                        $res = Invoke-AzRestMethod -Method GET -Path $uri
                        $functionAppObj = $res.Content | ConvertFrom-Json
                        
                        $parms.Url = "https://$($functionAppObj.properties.defaultHostName)/api"
                    }
                }
                Default { $res = "Non Azure Backend" }
            }

            if ($backendItem.Credential) {
                $credential = [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementBackendCredential]::new()
                $credential.Certificate = [Collections.Generic.List[String]]$backendItem.Credential.Certificate
                
                if ($backendItem.Credential.Query) {
                    $credential.Query = @{ }
                
                    foreach ($queryProp in $($backendItem.Credential.Query.PsObject.Properties)) {
                        #TODO: Check if value is an array like Credential.Header
                        $credential.Query."$($queryProp.Name)" = $queryProp.Value
                    }
                }
                else {
                    $credential.Query = $null
                }

                if ($backendItem.Credential.Header) {
                    $credential.Header = @{ }

                    #TODO: All hashtables could be handled by: ConvertTo-HashtableFromPsCustomObject
                    # https://omgdebugging.com/2019/02/25/convert-a-psobject-to-a-hashtable-in-powershell/
                    foreach ($headerProp in $($backendItem.Credential.Header).PsObject.Properties) {
                        $credential.Header."$($headerProp.Name)" = @($headerProp.Value)
                    }
                }
                else {
                    $credential.Header = $null
                }

                #TODO: This is an object and not a string. Needs to be mapped correctly
                $credential.Authorization = $backendItem.Credential.Authorization

                $parms.Credential = $credential
            }
            
            $res = New-AzApiManagementBackend -Context $ApimContext @parms

            if (-not $res) {
                $messageString = "Unable to deploy the Backend: <c='em'>$($backendItem.BackendId)</c>."
                Write-PSFMessage -Level Host -Message $messageString -Target $backendItem.BackendId
                Stop-PSFFunction -Message "The request either failed or hit a time out." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
                return
            }

            if ($PassThru) { $res }
        }
    }
    
    end {
        
    }
}