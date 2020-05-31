function Get-ConUSB
{
    $setUpapi = Get-Item "$env:SystemRoot\inf\Setupapi.dev.log"
    $reader = [System.IO.File]::ReadAllLines($setUpapi)
    $Reg = @("Registry::HKLM\SYSTEM\ControlSet001\Enum\USBSTOR\*\*\","Registry::HKLM\SYSTEM\ControlSet002\Enum\USBSTOR\*\")
    [array]$USBArr = $null

    [array]$Device = ((Get-Item "Registry::HKLM\SYSTEM\MountedDevices").Property)
    $Property = (Get-ItemProperty "Registry::HKLM\SYSTEM\MountedDevices")
    [array]$Path = $null

    foreach($proCnt in 0..($Device.Count - 1) )
    {
        $binaryData = $Property.($Device[$proCnt])
        $binaryCnt  = $binaryData.Count

        $BinaryReader = New-Object IO.BinaryReader (New-Object IO.MemoryStream (,$binaryData))
        $Path += New-Object -TypeName PSobject -Property @{ 
                        'path' = [Text.Encoding]::Unicode.GetString($BinaryReader.ReadBytes($binaryCnt))
                        'guid' = ($Device[$proCnt]) }
    }
    $BinaryReader.BaseStream.Dispose()

    $Prof = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | Where-Object { $_.ProfileImagePath -like "*Users*"})
    foreach( $usbInfo in Get-ItemProperty $Reg[0] )
    {
        $connectTime = [DateTime]::MinValue
        foreach($lineNum in 0..($reader.Count-1) )
        {
            if($reader[$lineNum] -match $usbinfo.PSChildName)
            {
                $readTime = $reader[$lineNum + 1]
                if($readTime -match "Section start")
                {
                    [DateTime][String]$connectTime = $readTime.Split(" ")[4..5]
                    break
                }
            }
        }
        if($connectTime -eq [DateTime]::MinValue) {
            $connectTime = (Get-Item $usbInfo.PSPath | Add-RegKeyMember).LastWriteTime
        }
    
        $Guid = $null; $DriveLe = $null; $UsPath = $null
        $path | Where-Object { $_.path -match $usbinfo.PSChildName } | % { $Guid = $_.guid }
        if($Guid -ne $null) {
            $Prof.PSChildName | ForEach-Object { if((Get-Item "Registry::HKU\$_\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\*").Name -like "*"+($Guid.split("{")[1]) ) { $UsPath = $Prof.ProfileImagePath; }}
        }
        Get-ItemProperty HKLM:\SOFTWARE\Microsoft\"Windows Portable Devices"\Devices\* | Where-Object { $_.PSChildName -like "*$($usbinfo.PSChildName)*" } | % { $DriveLe = $_.FriendlyName }
    
        $DeviceName = "FriendlyName"
        if(!$usbInfo.FriendlyName) { $DeviceName = "DeviceDesc"} 
        $USBArr += New-Object -TypeName PSobject -Property @{
                                                             'Description'     =  $usbInfo.$DeviceName
                                                             'Serial_Number'   =  $usbinfo.PSChildName
                                                             'Connection_Time' =  $connectTime
                                                             'Guid'            =  $Guid
                                                             'DriveLetter'     =  $DriveLe
                                                             'User_Profile'    = "$UsPath"
                                                            }
    }
    return $USBArr
}