@{
	# Script module or binary module file associated with this manifest
	RootModule        = 'PsApim.psm1'
	
	# Version number of this module.
	ModuleVersion     = '0.0.10'
	
	# ID used to uniquely identify this module
	GUID              = '2ffac7b4-e40f-4fee-a879-a6428a98cb34'
	
	# Author of this module
	Author            = 'Mötz Jensen'
	
	# Company or vendor of this module
	CompanyName       = 'Essence Solutions P/S'
	
	# Copyright statement for this module
	Copyright         = 'Copyright (c) 2020 Mötz Jensen'
	
	# Description of the functionality provided by this module
	Description       = 'A set of tools to assist with the different tasks around Azure API Management (APIM), from development to running it in production.'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.0'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules   = @(
		@{ ModuleName = 'PSFramework'; ModuleVersion = '1.4.150' }
		@{ ModuleName = 'Az.ApiManagement'; ModuleVersion = '2.1.0' }
		
	)
	
	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @('bin\PsApim.dll')
	
	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @('xml\PsApim.Types.ps1xml')
	
	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess = @('xml\PsApim.Format.ps1xml')
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Connect-PsApim',
		'Deploy-PsApimApi',
		'Export-PsApimApi',
		'Get-PsApimApi'
	)
	
	# Cmdlets to export from this module
	CmdletsToExport   = ''
	
	# Variables to export from this module
	VariablesToExport = ''
	
	# Aliases to export from this module
	AliasesToExport   = ''
	
	# List of all modules packaged with this module
	ModuleList        = @()
	
	# List of all files packaged with this module
	FileList          = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData       = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags         = @("API", "APIM", "AzureAPIM", "ApiManagement")
			
			# A URL to the license for this module.
			LicenseUri   = "https://opensource.org/licenses/MIT"
			
			# A URL to the main website for this project.
			ProjectUri   = "https://github.com/ApimCollaborative/PsApim"
			
			# A URL to an icon representing this module.
			# IconUri = ''
			
			# Indicates this is a pre-release/testing version of the module.
			IsPrerelease = "True"

			# ReleaseNotes of this module
			# ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}