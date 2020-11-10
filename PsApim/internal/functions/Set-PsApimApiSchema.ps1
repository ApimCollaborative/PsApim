function Set-PsApimApiSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsCustomObject] $ApiSchema,

        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext,

        [string] $SubscriptionId,

        [switch] $PassThru
    )
    
    begin {
    }
    
    process {
        if ((-not $ApiSchema.SchemaId) -or (-not $ApiSchema.SchemaFile)) {
            return
        }
        
        Write-PSFMessage -Level Verbose -Message "Setting the Schema for the Api: $($ApiSchema.ApiId)."
        
        $schemaString = Get-Content -Path $ApiSchema.SchemaFile -Encoding utf8 -Raw
        $uri = "subscriptions/$SubscriptionId/resourceGroups/$($ApimContext.ResourceGroupName)/providers/Microsoft.ApiManagement/service/$($ApimContext.ServiceName)/apis/$($ApiSchema.ApiId)/schemas/$($ApiSchema.SchemaId)`?api-version=2019-12-01"
        
        $res = Invoke-AzRestMethod -Method PUT -Path $uri -Payload $schemaString
        
        if (-not $res -or $res.StatusCode -NotLike "2*") {
            $res
            $res.Content
            $messageString = "Unable to upload the schema: <c='em'>$($ApiSchema.SchemaId)</c> for the specified API: <c='em'>$($ApiSchema.ApiId)</c>."
            Write-PSFMessage -Level Host -Message $messageString -Target $res
            Stop-PSFFunction -Message "Something went wrong when uploading the schema. Please make sure that the schema is valid." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
            return
        }

        if ($PassThru) { $res }

        $res = Invoke-AzRestMethod -Method GET -Path $uri
        
        if (-not $res -or $res.StatusCode -NotLike "2*") {
            $res
            $res.Content
            $messageString = "Unable to fetch the schema: <c='em'>$($ApiSchema.SchemaId)</c> for the specified API: <c='em'>$($ApiSchema.ApiId)</c>."
            Write-PSFMessage -Level Host -Message $messageString
            Stop-PSFFunction -Message "Something went wrong when getting the schema. There might be issues with the connection to Azure." -Exception $([System.Exception]::new($($messageString -replace '<[^>]+>', ''))) -StepsUpward 1
            return
        }

        if ($PassThru) { $res.Content }
    }
    
    end {
        
    }
}