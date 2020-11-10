<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

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

        if (Test-PSFFunctionInterrupt) { return }

        $apiObjectOnly = [System.Management.Automation.PSSerializer]::Deserialize([System.Management.Automation.PSSerializer]::Serialize($apiObject))
        $apiObjectOnly.PSObject.Properties.Remove('Backends')
        $apiObjectOnly.PSObject.Properties.Remove('Operations')
        $apiObjectOnly.PSObject.Properties.Remove('Products')

        Set-PsApimApi -Api $apiObjectOnly -Path $basePath -ApimContext $ApimContext -PassThru:$PassThru
        
        if (Test-PSFFunctionInterrupt) { return }

        $apiSchemaObject = [PsCustomObject]@{
            ApiId      = $apiObject.ApiId
            SchemaId   = $apiObject.SchemaId
            SchemaFile = $(Join-PSFPath -Path $basePath -Child $apiObject.SchemaFile)
        }
        Set-PsApimApiSchema -ApimContext $ApimContext -ApiSchema $apiSchemaObject -PassThru:$PassThru

        if (Test-PSFFunctionInterrupt) { return }

        Set-PsApimBackend -ApimContext $ApimContext -Backend $apiObject.Backends -PassThru:$PassThru

        if (Test-PSFFunctionInterrupt) { return }

        Set-PsApimOperation -ApimContext $ApimContext -ApiId $apiObject.ApiId -Path $basePath -Operation $apiObject.Operations -PassThru:$PassThru

        if (Test-PSFFunctionInterrupt) { return }
    }
    
    end {
        
    }
}