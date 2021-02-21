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
    Run controller used to deploy the resources to the cluster, monitor the pods, dispose the resources of the cluster, export the results to local host.
#>

. ".\services\LoggingService.ps1"
. ".\services\KubectlService.ps1"
. ".\services\AksService.ps1"

function Clear-Deployments {
    
    Clear-KubectlDeployments -Kind "deployment"
    Clear-KubectlDeployments -Kind "pod"
    Clear-KubectlDeployments -Kind "pvc"
    Clear-KubectlDeployments -Kind "pv"
    Clear-KubectlDeployments -Kind "svc"
    Clear-KubectlDeployments -Kind "configmap"
}

function Wait-ClusterReady {

    param(
       [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
       [PSCustomObject] $ClusterParameters,
       [Parameter ( Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName = $True )]
       [int] $Timeout = 500
    )

    $IsLocal = $ClusterParameters.IsLocal
    $Wait = $ClusterParameters.Wait
    $Name = $ClusterParameters.Name
    $ResourceGroup = $ClusterParameters.ResourceGroup

    if( $IsLocal -eq $False ) {

        if ( $Wait -eq $False ) {

            Wait-AksClusterState -ResourceGroup $ResourceGroup -Name $Name -State "created"
        }
        
        Get-AksCredentials -ResourceGroup $ResourceGroup -Name $Name
    }

    Set-KubectlContext $Name
}

function Add-Deployments {

    param(
       [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
       [PSCustomObject[]] $Deployments,
       [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
       [String] $Script
    )

    Clear-Deployments | Out-Null

    ForEach ( $Deployment in $Deployments ) {
        
        if ( $Deployment.Type -eq "configmap" ) {
            
            Add-LocustConfigMap -Name $Deployment.Name -ScriptPath $Script -ConfPath $Deployment.Path
        }

        else {

            Add-KubectlDeployment -Name $Deployment.Name -Filepath $Deployment.Path

            if ( $Deployment.Type -eq "pod" ) {

                Wait-PodCondition -Condition "Ready" -PodName $Deployment.Name
            }
            
            elseif ( $Deployment.Type -eq "deployment" ) {
            
                Wait-DeploymentReady -Deployment $Deployment.Name
                Wait-PodsReady -PodNames (( Get-PodList ).Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries ))
            }
        }
    }
}

function Wait-PodsReady {

    param(
       [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
       [string[]] $PodNames,
       [Parameter ( Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName = $True )]
       [int] $Timeout = 180
    )

    try {

        Write-TimestampOutput -Message "[Started] Waiting for pods ready"

        Wait-MultiplePodConditions -Condition "Ready" -PodNames $PodNames
    
        Write-TimestampOutput -Message "[Done] Waiting for pods ready - Success"
    }
    catch {

        Write-TimestampOutput -Message "[Done] Waiting for pods ready - Failure"
        Write-Error $_ -ErrorAction Stop
    }
}

function Wait-DeploymentReady {

    param(
        [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
        [string] $Deployment,
        [Parameter ( Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName = $True )]
        [int] $Timeout = 180
     )
 
     try {
 
         Write-TimestampOutput -Message "[Started] Waiting for pods ready"
 
         Wait-DeploymentCondition -Condition "Available" -Deployment $Deployment
     
         Write-TimestampOutput -Message "[Done] Waiting for pods ready - Success"
     }
     catch {
 
         Write-TimestampOutput -Message "[Done] Waiting for pods ready - Failure"
         Write-Error $_ -ErrorAction Stop
     }
}

function Wait-LoadTestEnd {

    param(
       [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
       [int] $RunTime,
       [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
       [String] $ServerPod
    )

    try {
 
        Write-TimestampOutput -Message "[Started] Waiting for load test"

        Wait-PodAnyCondition -Conditions "Failed","Succeeded" -PodName $ServerPod -Namespace "default" -Timeout $RunTime

        Write-TimestampOutput -Message "[Done] Waiting for load test - Success"
    }
    catch {

        Write-TimestampOutput -Message "[Done] Waiting for load test - Failure"
        Write-Error $_ -ErrorAction Stop
    }
    
}

function Export-TestResults {

    param(
       [Parameter ( Mandatory = $True, Position = 0, ValueFromPipelineByPropertyName = $True )]
       [String] $SourcePath,
       [Parameter ( Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True )]
       [String] $DestinationPath,
       [Parameter ( Mandatory = $True, Position = 2, ValueFromPipelineByPropertyName = $True )]
       [String] $ServerPod
    )

    try {
        
        Write-TimestampOutput -Message "---[Result export started]---"

        Remove-Item -Path "$DestinationPath*" -Recurse -Force

        Wait-PodCondition -Condition "Ready" -PodName $ServerPod

        Copy-PodToLocal -PodName $ServerPod -SourcePath $SourcePath -DestinationPath $DestinationPath

        if( (Get-ChildItem $DestinationPath | Measure-Object).Count -eq 0 ) {

            throw "Empty results."
        }

        Write-TimestampOutput -Message "---[Result export done]--- success`r`n"
    }
    catch {

        Write-TimestampOutput -Message "---[Result export done]--- failure`r`n"
        Write-Error $_
    }
}