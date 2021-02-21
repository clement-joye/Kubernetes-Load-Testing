<# 
PSScriptInfo 
.VERSION 1.0 
.AUTHOR Clément Joye 
.COMPANYNAME ADACA Authority AB 
.COPYRIGHT (C) 2020 Clément Joye / ADACA Authority AB - All Rights Reserved 
.LICENSEURI https://github.com/clement-joye/Kubernetes-Load-Testing/blob/main/LICENSE 
.PROJECTURI https://github.com/clement-joye/Kubernetes-Load-Testing
#>
#Requires -Version 5
<#
    .SYNOPSIS
    Configuration controller used to initialize the configuration, create the deployment/configuration files, dispose the deployment/configuration files. 
#>

. ".\services\LoggingService.ps1"

 function New-Configuration {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [String] $Path
    )

    try { 

        Write-TimestampOutput -Message "---[Configuration started]---"

        $FileContent = Get-Content -Raw -Path $Path
        $Configuration = $FileContent | ConvertFrom-Json 

        Write-TimestampOutput -Message "---[Configuration done]--- success`r`n"
    }
    catch {

        Write-TimestampOutput -Message "---[Configuration done]--- failure`r`n"
        Write-Error $_ -ErrorAction Stop
    }
    
    $Configuration
}

function Initialize-LocustConfigurationFile {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [PSCustomObject] $Parameters,
        [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [String] $Path
    )

    try { 

        Write-TimestampOutput -Message "---[Prepare locust configuration started]---"

        $Content = Get-ConfigurationContent -Parameters $Parameters
        
        Write-TimestampOutput -Message $Content

        New-Item -Path $Path -ItemType "file" -Value $Content -Force

        Write-TimestampOutput -Message "---[Prepare loucst configuration done]--- success`r`n"
    }
    catch {

        Write-TimestampOutput -Message "---[Prepare locust configuration done]--- failure`r`n"
        Write-Error $_ -ErrorAction Stop
    }
}

function Initialize-LocustDeploymentFile {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [PSCustomObject] $LocustParameters,
        [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [PSCustomObject] $TemplateParameters,
        [Parameter ( Mandatory = $True, Position = 2, ValueFromPipelineByPropertyName = $True )]
        [String] $SourcePath,
        [Parameter ( Mandatory = $True, Position = 3, ValueFromPipelineByPropertyName = $True )]
        [String] $DestinationPath
    )

    $Template = (Get-Content -Path $SourcePath -Raw)

    $Parameters = $LocustParameters.PsObject.Properties + $TemplateParameters.PsObject.Properties
    
    ForEach ( $Parameter in $Parameters ) { 
        
        $Template = $Template -replace "{$( $Parameter.Name )}", $Parameter.Value 
    }

    Write-TimestampOutput "Creating $DestinationPath with value:`r`n$Template"
    
    New-Item -Path $DestinationPath -ItemType "file" -Value $Template -Force | Out-Null
    
}

function Get-ConfigurationContent {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [PSCustomObject] $Parameters   
    )

    $Bloc = ''

    ForEach ( $Parameter in $Parameters.PSObject.Properties ) { 
        
        $Bloc += "$($Parameter.Name) = $($Parameter.Value)" + ([Environment]::NewLine) 
    }

    Write-TimestampOutput -Message "`r`n$Bloc"

    $Bloc
}

function Get-Runtime {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [PSCustomObject] $ServerParameters  
    )

    $RunTime = 10

    $Configuration.Server.PSObject.Properties | ForEach-Object {
        
        if( $_.Name -eq "run-time" ) {
            
            $RunTimeRaw = $_.Value

            if ( $RunTimeRaw -match '[0-9]+[hm]' ) {

                ForEach ( $Value in $Matches.Values ) {
        
                    if ( $Value -like "*m") { $RunTime += [int]($Value.Replace('m', '')) * 60 }
                    
                    if ( $Value -like "*h") { $RunTime += [int]($Value.Replace('h', '')) * 3600 }
                }
            }
        }
    }

    if( $RunTime -eq 10) { throw "No run-time specified or run-time invalid." }

    $RunTime
}

function Clear-Directory {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [String] $Path  
    )

    try {

        Write-TimestampOutput -Message "---[Started] Removing Deployment Files."
        
        if ( (Test-Path $Path) -eq $True ) {

            Remove-Item –Path $Path  –Recurse -Force
        }
        
        Write-TimestampOutput -Message "---[Done] Removing Deployment Files."
    }
    catch {

        Write-Error $_
    }
}