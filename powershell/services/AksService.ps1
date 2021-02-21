<# 
PSScriptInfo 
.VERSION 1.0 
.COMPANYNAME ADACA Authority AB 
.COPYRIGHT (C) 2020 Clément Joye / ADACA Authority AB - All Rights Reserved 
.LICENSEURI https://github.com/clement-joye/Kubernetes-Load-Testing/blob/main/LICENSE 
.PROJECTURI https://github.com/clement-joye/Kubernetes-Load-Testing
#>
#Requires -Version 5
<#
    .SYNOPSIS
    Utility functions for AKS: Get-Credentials, Cluster list, wait for state, create cluster, remove cluster. 
#>

. ".\services\LoggingService.ps1"

function Get-AksCredentials {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [String] $ResourceGroup,
        [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [String] $Name
    )
    
    Write-TimestampOutput -Message "[Started] Getting credentials."

    az aks get-credentials -g $ResourceGroup -n $Name --overwrite-existing
    
    Write-TimestampOutput -Message "[Done] Getting credentials."
}

function Get-AksClusterList {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [String] $ResourceGroup,
        [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [String] $Name
    )

    (az aks list --query "[?resourceGroup=='$ResourceGroup' && name=='$Name' && provisioningState=='Succeeded'].{Name:name, State:provisioningState, NodeCount: agentPoolProfiles[].count}" |  convertfrom-Json)
}

function Wait-AksClusterState {
    
    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [String] $ResourceGroup,
        [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [String] $Name,
        [Parameter ( Mandatory = $True, Position = 2, ValueFromPipelineByPropertyName = $True )]
        [String] $State,
        [Parameter ( Mandatory = $False, Position = 3, ValueFromPipelineByPropertyName = $True )]
        [int] $Timeout = 300
    )

    Write-TimestampOutput -Message "[Started] Creating Cluster."

    az aks wait --$State --interval 15 -g $ResourceGroup -n $Name --timeout $Timeout
    
    Write-TimestampOutput -Message "[Done] Creating Cluster."
}

function New-AksCluster {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [String] $ResourceGroup,
        [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [String] $Name,
        [Parameter ( Mandatory = $True, Position = 2, ValueFromPipelineByPropertyName = $True )]
        [String] $NodeCount,
        [Parameter ( Mandatory = $True, Position = 3, ValueFromPipelineByPropertyName = $True )]
        [String] $VmSize
    )
    
    Write-TimestampOutput -Message "[Started] Creating Cluster."

    az aks create -g $ResourceGroup -n $Name -c $NodeCount -s $VmSize --generate-ssh-keys --no-wait
    
    Write-TimestampOutput -Message "[Done] Creating Cluster."
}

function Remove-AksCluster {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [String] $ResourceGroup,
        [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [String] $Name,
        [Parameter ( Mandatory = $False, Position = 2, ValueFromPipelineByPropertyName = $True )]
        [bool] $Wait = $False
    )
    
    Write-TimestampOutput -Message "[Started] Removing Cluster."
    
    if ( $Wait -eq $True ) {

        az aks delete -g $ResourceGroup -n $Name --yes
    }
    else {

        az aks delete -g $ResourceGroup -n $Name --no-wait --yes
    } 

    Write-TimestampOutput -Message "[Done] Removing Cluster."
}