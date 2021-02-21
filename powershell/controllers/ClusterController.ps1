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
    Cluster controller used to create a cluster, dipose a cluster
#>

. ".\services\LoggingService.ps1"
. ".\services\AksService.ps1"

function Add-Cluster {

    param(
       [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
       [PSCustomObject] $ClusterParameters,
       [Parameter ( Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName = $True )]
       [int] $Timeout = 500
    )

    try { 

        Write-TimestampOutput -Message "---[Cluster Creation started]---"
        
        if( $ClusterParameters.IsLocal -eq $False ) {

            $ResourceGroup = $ClusterParameters.ResourceGroup
            $Name = $ClusterParameters.Name
            

            if ( (Get-AksClusterList -ResourceGroup $ResourceGroup -Name $Name).Count -eq 0 ) {

                $NodeCount = $ClusterParameters.NodeCount
                $VmSize = $ClusterParameters.VmSize

                New-AksCluster -ResourceGroup $ResourceGroup -Name $Name -NodeCount $NodeCount -VmSize $VmSize
            }

            if ( $ClusterParameters.Wait -eq $True ) {

                Wait-AksClusterState -ResourceGroup $ResourceGroup -Name $Name -State "created" -Timeout 500
            }
        }
        
        Write-TimestampOutput -Message "---[Cluster Creation done]--- success`r`n"
    }
    catch {

        Write-TimestampOutput -Message "---[Cluster Creation done]--- failure`r`n"
        Write-Error $_
    }

    $Success
}

function Remove-Cluster {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [PSCustomObject] $ClusterParameters
    )

    try { 
        
        Write-TimestampOutput -Message "---[Cluster Deletion started]---"

        if($ClusterParameters.IsLocal -eq $False) {

            $ResourceGroup = $ClusterParameters.ResourceGroup
            $Name = $ClusterParameters.Name
            $Wait = $ClusterParameters.Wait

            Remove-AksCluster -ResourceGroup $ResourceGroup -Name $Name -Wait $Wait
        }

        Write-TimestampOutput -Message "---[Cluster Deletion done]--- success`r`n"
    }
    catch {

        Write-TimestampOutput -Message "---[Cluster Deletion done]--- failure`r`n"
        Write-Error $_
    }
}

