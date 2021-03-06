function Get-UserAssist
{
    [array]$Table = $null
    $RegPath = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\*\*\"
    Get-ChildItem $RegPath | Where-Object { $_.Name -like "*Count" } | ForEach-Object {
        $PropertyData = Get-ItemProperty $_.PSPath

        foreach($Reg_pro in $_.Property)
        {
            [string]$Decoded = ""
            foreach ($CipherChar in $Reg_pro.ToCharArray()) {
                switch ($CipherChar) {
                    { $_ -ge 65 -and $_ -le 90 } { $Decoded += (((($_ - 65 - 13) % 26 + 26) % 26) + 65) | % { [char]$_ } } # Uppercase characters
                    { $_ -ge 97 -and $_ -le 122 } { $Decoded += (((($_ - 97 - 13) % 26 + 26) % 26) + 97) | % { [char]$_ } } # Lowercase characters
                    default { [string]$Decoded += $CipherChar } # Pass through symbols and numbers
                }
            }
            [array]$BinaryData = $PropertyData.$Reg_pro
            $FileTime = switch ($BinaryData.Count) {
                    8 { [datetime]::FromFileTime(0) }
                    16 { [datetime]::FromFileTime([BitConverter]::ToInt64($BinaryData[8..15],0)) }
                    default { [datetime]::FromFileTime([BitConverter]::ToInt64($BinaryData[60..67],0)) }
                }
            $Table += New-Object -TypeName psobject -Property @{ Path = $Decoded
                                                     LastModifiedTime = $FileTime
                                                               Source = $RegPath  + $Reg_pro
                                                        }
        }
    }
    return $Table
}