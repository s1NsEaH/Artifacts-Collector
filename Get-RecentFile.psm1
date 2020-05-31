function Get-RecentFile
{
    [array]$FileTable = $null
    $RecentFile = @("HKCU:\Software\Microsoft\Office\*\Excel\File MRU\", "HKCU:\Software\Microsoft\Office\*\Word\File MRU\", "HKCU:\Software\Microsoft\Office\*\PowerPoint\File MRU\")
    foreach( $i in 0..($RecentFile.Count - 1) ) {
        foreach( $iTem in (Get-Item $RecentFile[$i]).Property ) {
            $FileTable += New-Object -TypeName PSobject -Property @{ Path  = (Get-ItemProperty $RecentFile).$iTem
                                                                    Source = $RecentFile[$i] }
        }
    }

    $Prof = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" | Where-Object { $_.ProfileImagePath -like "*Users*"})
    $Prof.PSChildName | ForEach-Object { if((Get-Item "Registry::HKU\$_\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\*").Name -like "*"+($Guid.split("{")[1]) ) { $UsPath = $Prof.ProfileImagePath; }}

    foreach($sID in $Prof.PSChildName)
    {
        $mruFile = "Registry::HKU\$sID\Software\Hnc\Hwp\*\HwpFrame\FileDialog\Settings\00020953\File MRU"
        (Get-Item $mruFile).Property | % {
            $FileTable += New-Object -TypeName PSobject -Property @{ `
              Path = [Text.Encoding]::Unicode.GetString((Get-ItemProperty $mruFile).$_)
            Source = $mruFile }
        }
    }
    return $FileTable
}