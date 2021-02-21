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
    Main entry point for Kubernetes Load Testing

    .DESCRIPTION
    Create a cluster or use an existing one to run a load test, then dispose all resources.

    .NOTES
    Can be run locally with Kubernetes installed or against Azure Kubernetes Service (AKS)

    .PARAMETER Mode
    Specifies the mode for the script. Default value: All

    .PARAMETER Environment
    Specifies the configuration file to use. Default value: DEBUG

    .INPUTS
    None. You cannot pipe objects to Invoke-K8sTests.

    .EXAMPLE
    PS> .\Invoke-K8sTests.ps1 -Mode "All" -Environment "DEBUG"
    PS> .\Invoke-K8sTests.ps1 -Mode "Create" -Environment "TEST"
    PS> .\Invoke-K8sTests.ps1 -Mode "Run" -Environment "TEST"
    PS> .\Invoke-K8sTests.ps1 -Mode "Dispose" -Environment "TEST"
#>

[CmdletBinding()]
Param (
    [Parameter ( Mandatory = $False, Position = 0, ValueFromPipelineByPropertyName = $True )]
    [String] $Mode = "All",
    [Parameter ( Mandatory = $False, Position = 1, ValueFromPipelineByPropertyName = $True )]
    [String] $Environment = "DEBUG"
)

Begin {

    . ".\controllers\ConfigurationController.ps1"
    . ".\controllers\ClusterController.ps1"
    . ".\controllers\RunController.ps1"
    . ".\services\LoggingService.ps1"
    . ".\services\KubectlService.ps1"

    $DebugPreference = "Continue"

    $ServerPod = "locust-server-pod"

    $Deployments = @(

        [PSCustomObject]@{ Type = "pv";         Name = "locust-report-pv";              Path = "..\k8s\locust-report-pv.yaml"                   },
        [PSCustomObject]@{ Type = "pvc";        Name = "locust-report-pvc";             Path = "..\k8s\locust-report-pvc.yaml"                  },
        [PSCustomObject]@{ Type = "configmap";  Name = "locust-server-cm";              Path = "..\deployments\server\locust.conf";             }
        [PSCustomObject]@{ Type = "configmap";  Name = "locust-client-cm";              Path = "..\deployments\client\locust.conf";             }
        [PSCustomObject]@{ Type = "service";    Name = "locust-server-service-connect"; Path = "..\k8s\locust-server-service-connect.yaml"      },
        [PSCustomObject]@{ Type = "service";    Name = "locust-server-service";         Path = "..\k8s\locust-server-service.yaml"              },
        [PSCustomObject]@{ Type = "pod";        Name = "locust-server-pod";             Path = "..\deployments\locust-server-pod.yaml"          },
        [PSCustomObject]@{ Type = "deployment"; Name = "locust-client-deployment";      Path = "..\deployments\locust-client-deployment.yaml"   }
    )
    
    function Configure {

        Get-Job | Remove-Job
        
        Clear-Logs | Out-Null

        $Configuration = New-Configuration -Path "..\config\config.$Environment.json"

        Foreach ($Property in $Configuration.PSObject.Properties) {

            Write-Debug $Property.Name
            Write-Debug "$( $Property.Value | Out-String ) `r`n"
        }

        # Clear directory
        Clear-Directory "..\deployments\" | Out-Null

        # Create Locust Configuration files
        Initialize-LocustConfigurationFile -Parameters $Configuration.Server -Path "..\deployments\server\locust.conf" | Out-Null
        Initialize-LocustConfigurationFile -Parameters $Configuration.Client -Path "..\deployments\client\locust.conf" | Out-Null

        # Create Locust deployment files
        Initialize-LocustDeploymentFile -LocustParameters $Configuration.Server -TemplateParameters $Configuration.Template -SourcePath "..\k8s\locust-server-pod.yaml" -DestinationPath "..\deployments\locust-server-pod.yaml" | Out-Null
        Initialize-LocustDeploymentFile -LocustParameters $Configuration.Client -TemplateParameters $Configuration.Template -SourcePath "..\k8s\locust-client-deployment.yaml" -DestinationPath "..\deployments\locust-client-deployment.yaml" | Out-Null

        # Get load test time limit 
        $RunTime = Get-Runtime -ServerParameters $Configuration.Server
    
        $Configuration, $RunTime
    }

    function Create {

        # Cluster
        Add-Cluster -ClusterParameters $Configuration.Cluster
    }
    
    function Run {

        try {

            # Wait for cluster ready
            Wait-ClusterReady -ClusterParameters $Configuration.Cluster
            
            # Deployments
            Add-Deployments -Deployments $Deployments -Script $Configuration.Script
            
            # Deployments
            Wait-LoadTestEnd -RunTime $RunTime -ServerPod $ServerPod

            # Export results
            Export-TestResults -SourcePath "/reports" -DestinationPath "../reports" -ServerPod $ServerPod

            # Clear resources from cluster
            Clear-Deployments

            # Remove deployment files
            Clear-Directory "..\deployments\"
        }
        catch {

            Write-Error $_ -ErrorAction Stop
        }
    }
    
    function Dispose {
    
        try {

            # Wait for cluster ready
            Wait-ClusterReady -ClusterParameters $Configuration.Cluster
            
            # Remove Cluster
            Remove-Cluster -ClusterParameters $Configuration.Cluster
        }
        catch {

            Write-Error $_ -ErrorAction Stop
        }
        
    }

    $Configuration, $RunTime = Configure
}

Process {
    
    switch ( $Mode ) {

        "All" {
            Create
            Run
        }

        "Create" {
            Create
        }

        "Run" {
            Create
            Run
        }
    }
}

End {

    switch ( $Mode ) {

        "All" {
            Dispose
        }

        "Dispose" {
            Dispose
        }
    }
}
