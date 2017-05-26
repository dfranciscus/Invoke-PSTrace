
#requires -Modules NetEventPacketCapture

function Invoke-PSTrace {
    [OutputType([System.Diagnostics.Eventing.Reader.EventLogRecord])]
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [switch]$OpenWithMessageAnalyzer,
        [pscredential]$Credential
    )
    
        DynamicParam 
        {
            $ParameterName = 'ETWProvider' 
            $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
            $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
            $ParameterAttribute.Mandatory = $true
            $AttributeCollection.Add($ParameterAttribute)
            $arrSet = logman query providers | Foreach-Object {$_.split('{')[0].trimend()} | Select-Object -Skip 3 | Select-Object -SkipLast 2
            $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
            $AttributeCollection.Add($ValidateSetAttribute)
            $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
            $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
            return $RuntimeParameterDictionary
        }

    begin 
    {
        $ETWProvider = $PsBoundParameters[$ParameterName]
        Get-CimSession -ComputerName $ComputerName -ErrorAction SilentlyContinue | Remove-CimSession -Confirm:$False
        Get-NetEventSession -Name "Session1" -ErrorAction SilentlyContinue | Remove-NetEventSession -Confirm:$False
        Remove-Item -Path "C:\Windows\Temp\$ComputerName-Trace.etl" -Force -Confirm:$False -ErrorAction SilentlyContinue
    }

    process 
    {
        try 
        {
            $Cim = New-CimSession -ComputerName $ComputerName -Credential $Credential
            New-NetEventSession -Name "Session1" -CimSession $Cim -LocalFilePath "C:\Windows\Temp\$ComputerName-Trace.etl" -CaptureMode SaveToFile -ErrorAction stop | out-null
            Add-NetEventProvider -CimSession $Cim -Name $ETWProvider -SessionName "Session1" -ErrorAction stop | out-null
            Start-NetEventSession -Name "Session1" -CimSession $Cim -ErrorAction stop | out-null
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            Write-Error -Message $ErrorMessage
            Get-NetEventSession -Name "Session1" -CimSession $Cim -ErrorAction SilentlyContinue | Remove-NetEventSession -Confirm:$False
            Get-CimSession -ComputerName $ComputerName -ErrorAction SilentlyContinue | Remove-CimSession -Confirm:$False
            Remove-Item -Path "C:\Windows\Temp\$ComputerName-Trace.etl" -Force -Confirm:$False -ErrorAction SilentlyContinue
            Return 
        }

        Read-Host 'Press enter to stop trace'  | Out-Null

        Stop-NetEventSession -Name 'Session1' -CimSession $Cim   
        Remove-NetEventProvider -Name $ETWProvider -CimSession $Cim  
        Remove-NetEventSession -Name 'Session1' -CimSession $Cim  
        Remove-CimSession -CimSession $Cim -Confirm:$False 
        if ($ComputerName -ne 'LocalHost')
        {
            Copy-Item -Path "\\$ComputerName\C$\Windows\Temp\$ComputerName-trace.etl" -Destination 'C:\Windows\Temp' -Force
        }
        Get-CimSession -ComputerName $ComputerName -ErrorAction SilentlyContinue | Remove-CimSession -Confirm:$False
        $log = Get-WinEvent -Path "C:\Windows\Temp\$ComputerName-trace.etl" -Oldest -MaxEvents 20000
        if ($OpenWithMessageAnalyzer)
        {
             Start-Process -FilePath 'C:\Program Files\Microsoft Message Analyzer\MessageAnalyzer.exe' -ArgumentList "C:\Windows\Temp\$ComputerName-trace.etl"
        }
        else 
        {
             $log 
        }
    }

}
