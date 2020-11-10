function Export-PsApimApi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ApiId,
    
        [PsfValidateScript('PSFramework.Validate.FSPath.Folder', ErrorString = 'PSFramework.Validate.FSPath.Folder')]
        [string] $Path,
        
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext = (Get-PsApimDefaultContext)

    )
    
    begin {
    }
    
    process {
        
        $operationPolicyPath = Join-PSFPath -Path $Path -Child "operation.policies" -Normalize
        $productPolicyPath = Join-PSFPath -Path $Path -Child "product.policies" -Normalize

        if (-not (Test-PathExists -Path $operationPolicyPath, $productPolicyPath -Type Container -Create)) { return }

        Write-PSFMessage -Level Verbose -Message "Getting the API from the APIM instance."
        $apiObject = $(Get-AzApiManagementApi -Context $ApimContext -ApiId $ApiId | ConvertTo-Json -Depth 10) | ConvertFrom-Json

        if (-not $apiObject) {
            $messageString = "Unable to find the specified API: <c='em'>$ApiId</c>."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "The API wasn't found. Please make sure that you have spelled the ApiId correct and that you're connected to the correct APIM instance." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', '')))
            return
        }
        
        # ApiVersionSetDescription is named ApiVersionDescription in the powershell cmdlet
        $apiObject | Add-Member -MemberType NoteProperty -Name "ApiVersionDescription" -Value $apiObject.ApiVersionSetDescription

        $propsToClearFromApi = @("ApiType", "ApiRevision", "IsCurrent", "IsOnline", "ApiRevisionDescription", "Id", "ResourceGroupName", "ServiceName", "ApiVersionSetDescription")
        foreach ($propName in $propsToClearFromApi) {
            $apiObject.PsObject.Properties.Remove($propName)
        }

        $schemaObj = Get-AzApiManagementApiSchema -Context $ApimContext -ApiId $ApiId

        $apiObject | Add-Member -MemberType NoteProperty -Name "SchemaId" -Value $null
        $apiObject | Add-Member -MemberType NoteProperty -Name "SchemaFile" -Value $null

        if ($schemaObj) {
            Write-PSFMessage -Level Verbose -Message "Getting the schema connected to the API."

            #! Hack to solve the issue with the built-in powershell cmdlet.
            $uriTemplate = "subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$($ApimContext.ResourceGroupName)/providers/Microsoft.ApiManagement/service/$($ApimContext.ServiceName)/apis/$ApiId/schemas/{schemaid}?api-version=2019-12-01"
            $uri = $uriTemplate -Replace "{schemaid}", "$($schemaObj.SchemaId)"
            $res = Invoke-AzRestMethod -Method GET -Path $uri

            $schemaString = $res.Content
            $schemaString = $schemaString -replace '\n.*"id":.*",', ''
            $schemaString = $schemaString -replace '\n.*"type":.*",', ''
            $schemaString = $schemaString -replace '\n.*"name":.*",', ''

            $apiSchemaFilePath = Join-PSFPath -Path $Path -Child "api.schema.json"
            $schemaString | Out-File -FilePath "$apiSchemaFilePath" -Encoding utf8

            $apiObject.SchemaId = $schemaObj.SchemaId
            $apiObject.SchemaFile = "api.schema.json"
        }

        Write-PSFMessage -Level Verbose -Message "Getting the policy connected to the API."
        $apiPolicyString = Get-AzApiManagementPolicy -Context $ApimContext -ApiId $ApiId
        $apiObject | Add-Member -MemberType NoteProperty -Name "ApiPolicyFile" -Value $null

        if ($apiPolicyString) {
            $apiPolicyFilePath = Join-PSFPath -Path $Path -Child "api.policy.json"
            $apiPolicyString | Out-File -FilePath "$apiPolicyFilePath" -Encoding utf8
            $apiObject.ApiPolicyFile = "api.policy.json"
        }

        Write-PSFMessage -Level Verbose -Message "Getting the operations from the API."
        $operations = @(Get-AzApiManagementOperation -Context $ApimContext -ApiId $ApiId)

        $propsToClearFromOperation = @("ApiId", "Id", "ResourceGroupName", "ServiceName")
        $propsToClearFromBackend = @("ServiceFabricCluster", "Credentials", "Properties", "Id", "ResourceGroupName", "ServiceName")

        $backendsHash = @{ }
        $operationsHash = @{ }
        
        foreach ($operationItem in $operations) {
            Write-PSFMessage -Level Verbose -Message "Working on the operation: $($operationItem.OperationId)." -Target $operationItem.OperationId

            #! Hack to make it possible to remove properties
            $operationObject = $($operationItem | ConvertTo-Json -Depth 10) | ConvertFrom-Json

            Write-PSFMessage -Level Verbose -Message "Getting the policy connected to the operation: $($operationItem.OperationId)." -Target $operationItem.OperationId
            $operationPolicyString = Get-AzApiManagementPolicy -Context $ApimContext -ApiId $ApiId -OperationId $operationObject.OperationId

            if ($operationPolicyString -match 'backend-id="(.*)"') {
                Write-PSFMessage -Level Verbose -Message "Backend is found in Policy for operation: $($operationItem.OperationId)." -Target $operationItem.OperationId
                # Test if operation policy is pointing toward LogicApp or Azure Function
                $backendId = $Matches[1]

                Write-PSFMessage -Level Verbose -Message "Getting the Backend: $backendId." -Target $backendId
                $backendObj = Get-AzApiManagementBackend -Context $ApimContext -BackendId $backendId

                #! Hack to make it possible to remove properties
                $backendObj = $($backendObj | ConvertTo-Json -Depth 10) | ConvertFrom-Json

                if ($backendObj.ResourceId -like "*Microsoft.Logic*") {
                    Write-PSFMessage -Level Verbose -Message "Backend: $backendId is a LogicApp" -Target $backendObj.ResourceId

                    # Test if operation / backend is LogicApp
                    $backendObj | Add-Member -MemberType NoteProperty -Name "BackendType" -Value "LogicApp"

                    #TODO: OperationPolicy contains named value, which is the signature key for invoking the LogicApp
                    # If LogicApps are using OAuth authentication, this is NOT true

                    if ($operationPolicyString -match '".*;sig={{(.*)}}"') {
                        $backendObj | Add-Member -MemberType NoteProperty -Name "BackendNamedValueId" -Value $Matches[1]
                    }
                }
                elseif ($backendObj.ResourceId -like "*Microsoft.Web*") {
                    Write-PSFMessage -Level Verbose -Message "Backend: $backendId is a FunctionApp/Azure Function" -Target $backendObj.ResourceId

                    # Test if operation / backend is Azure Function
                    $backendObj | Add-Member -MemberType NoteProperty -Name "BackendType" -Value "FunctionApp"

                    if ($backendObj.Credentials.Header."x-functions-key") {
                        if ($($backendObj.Credentials.Header."x-functions-key") -match '{{(.*)}}') {
                            $backendObj | Add-Member -MemberType NoteProperty -Name "BackendNamedValueId" -Value $Matches[1]
                            $backendObj | Add-Member -MemberType NoteProperty -Name "FunctionAppKeyName" -Value "ThisIsMyApimKey"
                        }
                    }
                }
        
                # Credentials is named Credential in the powershell cmdlet
                $backendObj | Add-Member -MemberType NoteProperty -Name "Credential" -Value $backendObj.Credentials
                $backendObj.Url = $null # If Url is null, we pull url at deploy time. If url -Not Null, then we use the value.

                foreach ($propName in $propsToClearFromBackend) {
                    $backendObj.PsObject.Properties.Remove($propName)
                }
        
                if (-not $backendObj.Title) {
                    $backendObj.Title = "$ApiId"
                }

                # $backendsHash.$backendId = $($backendObj | ConvertTo-Json -Depth 10)
                $backendsHash.$backendId = $backendObj
            }

            #TODO: PolicyString might contain multiple NamedValueReferences
            # Exclude logic app reference, if it is found.

            foreach ($propName in $propsToClearFromOperation) {
                $operationObject.PsObject.Properties.Remove($propName)
            }

            #TODO: Path / name for policy file needs to be filled
            $operationObject | Add-Member -MemberType NoteProperty -Name "OperationPolicyFile" -Value $null

            if ($operationPolicyString) {
                $operationPolicyFilePath = Join-Path -Path $operationPolicyPath -ChildPath "$($operationObject.OperationId).policy.xml"

                Write-PSFMessage -Level Verbose -Message "Writing policy file for operation: $($operationItem.OperationId)." -Target $operationPolicyFilePath
                $operationPolicyString | Out-File -FilePath $operationPolicyFilePath -Encoding utf8
                $operationObject.OperationPolicyFile = "$($operationObject.OperationId).policy.xml"
            }

            $operationsHash."$($operationObject.OperationId)" = $operationObject
        }
        
        $apiObject | Add-Member -MemberType NoteProperty -Name "Backends" -Value @($backendsHash.Values)
        $apiObject | Add-Member -MemberType NoteProperty -Name "Operations" -Value @($operationsHash.Values)

        Write-PSFMessage -Level Verbose -Message "Getting the products connected to the API."
        $products = @(Get-AzApiManagementProduct -Context $ApimContext -ApiId $ApiId)
        $propsToClearFromProduct = @("Id", "ResourceGroupName", "ServiceName")

        $productsHash = @{ }

        foreach ($productItem in $products) {
            Write-PSFMessage -Level Verbose -Message "Working on the product: $($productItem.ProductId)." -Target $productItem.ProductId

            Write-PSFMessage -Level Verbose -Message "Getting the policy connected to the product: $($productItem.ProductId)." -Target $productItem.ProductId
            $productPolicyString = Get-AzApiManagementPolicy -Context $ApimContext -ProductId $productItem.ProductId

            #! Hack to make it possible to remove properties
            $productObj = $($productItem | ConvertTo-Json -Depth 10) | ConvertFrom-Json
            $productId = $productItem.Productd

            foreach ($propName in $propsToClearFromProduct) {
                $productObj.PsObject.Properties.Remove($propName)
            }

            $productObj | Add-Member -MemberType NoteProperty -Name "ProductPolicyFile" -Value $null

            if ($productPolicyString) {
                $productPolicyFilePath = Join-Path -Path $productPolicyPath -ChildPath "$($productItem.ProductId).policy.xml"
                
                Write-PSFMessage -Level Verbose -Message "Writing policy file for product: $($productItem.ProductId)." -Target $productPolicyFilePath
                $productPolicyString | Out-File -FilePath $productPolicyFilePath -Encoding utf8
                $productObj.ProductPolicyFile = "$($productItem.ProductId).policy.xml"
            }

            $productsHash.$productId = $productObj
        }

        $apiObject | Add-Member -MemberType NoteProperty -Name "Products" -Value @($productsHash.Values)

        $apiFilePath = Join-Path -Path $Path -ChildPath "api.json"

        Write-PSFMessage -Level Verbose -Message "Writing the api file for api: $ApiId." -Target $ApiId
        $($apiObject | ConvertTo-Json -Depth 10) | Out-File -FilePath "$apiFilePath" -Encoding utf8
    }
    
    end {
        
    }
}