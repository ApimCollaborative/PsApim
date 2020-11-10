function Deploy-PsApimApi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PsfValidateScript('PSFramework.Validate.FSPath.FileOrParent', ErrorString = 'PSFramework.Validate.FSPath.FileOrParent')]
        [string] $Path,
        
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext] $ApimContext = (Get-PsApimDefaultContext),

        [switch] $PassThru
    )
    
    begin {

        if ($Path -NotLike "*.json") {
            $Path = Join-PSFPath -Path $Path -Child "api.json"
        }

        if (-not (Test-PathExists -Path $Path -Type Leaf)) {
            return
        }
    }
    
    process {
        if (Test-PSFFunctionInterrupt) { return }
        
        $apiObject = Get-Content -Path $Path -Raw -Encoding utf8 | ConvertFrom-Json
        $basePath = Split-Path -Path $Path -Parent

        Set-PsApimProduct -Product $apiObject.Products -Path $basePath -ApimContext $ApimContext -PassThru:$PassThru

        $apiObjectOnly = [System.Management.Automation.PSSerializer]::Deserialize([System.Management.Automation.PSSerializer]::Serialize($apiObject))
        $apiObjectOnly.PSObject.Properties.Remove('Backends')
        $apiObjectOnly.PSObject.Properties.Remove('Operations')
        $apiObjectOnly.PSObject.Properties.Remove('Products')

        Set-PsApimApi -Api $apiObjectOnly -Path $basePath -ApimContext $ApimContext -PassThru:$PassThru

        # ."$PSScriptRoot\Set-PsApimApiSchema.ps1"
        # $apiFolder = Split-Path -Path $Path -Parent
        $apiSchemaObject = [PsCustomObject]@{
            ApiId      = $apiObject.ApiId
            SchemaId   = $apiObject.SchemaId
            SchemaFile = $(Join-PSFPath -Path $basePath -Child $apiObject.SchemaFile)
        }
        Set-PsApimApiSchema -ApimContext $ApimContext -ApiSchema $apiSchemaObject -PassThru:$PassThru


        # ."$PSScriptRoot\Set-PsApimBackend.ps1"
        # #Arrays with single entries, doesn't produce correct array objects when piped.
        # ConvertTo-Json -InputObject $apiObject.Backends -Depth 5 | Set-PsApimBackend -ApimContext $context

        # ."$PSScriptRoot\Set-PsApimOperation.ps1"
        # #Arrays with single entries, doesn't produce correct array objects when piped.
        # ConvertTo-Json -InputObject $apiObject.Operations -Depth 4 | Set-PsApimOperation -ApimContext $context -ApiId $apiObject.ApiId -Path $apiFolder
    }
    
    end {
        
    }
}