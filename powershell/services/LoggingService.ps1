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
    Utility functions for logging.
#>

function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

function Clear-Logs {

    if( ( Test-Path -Path "..\logging\") -eq $True ) {

        Remove-Item -Path "..\logging\" -Recurse -Force
    }

    New-Item -Path "..\logging\" -ItemType Directory -Force
    New-Item -Path "..\logging\log.txt" -ItemType File -Force
}

Function Log {

    param(
        [Parameter( Mandatory=$True )]
        [String] $Message
    )
    
    Add-Content "..\logging\log.txt" $Message
}

function Write-TimestampOutput {

    param(
       [Parameter(Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True)]
       [String] $Message,
       [Parameter(Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName = $True)]
       [String] $Level = "Debug"
    )

    switch ( $Level ) {
        
        "Debug" { 
            Write-Debug "$(Get-TimeStamp) $Message"
        }

        "Output" {
            Write-Output "$(Get-TimeStamp) $Message"
        }

        "Host" { 
            Write-Host "$(Get-TimeStamp) $Message"
        }
    }

    Log -Message $Message
}