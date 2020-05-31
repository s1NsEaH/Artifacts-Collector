function Get-Autoruns
{
    $runPath = @("Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                 "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                 "Registry::HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows\Run",
                 "Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
                 "Registry::HKLM\Software\Microsoft\Windows\CurrentVersion\policies\Explorer\Run")
    [array]$AutorunsPath = $null

    foreach($run in $runPath)
    {
        if(Test-Path $run)
        {
             $Autoruns = Get-Item $run
             $Autoruns.Property | % { if($Autoruns.GetValue($_) -match '"') {
                $AutorunsPath += New-Object -TypeName PSobject -Property @{ Path = $Autoruns.GetValue($_).split('"')[1]
                                                                          Source = $run }
                } else {
                $AutorunsPath += New-Object -TypeName PSobject -Property @{ Path = $Autoruns.GetValue($_)
                                                                          Source = $run }
                } # else
             } # if
        } # if
    } # foreach

    $startupPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\"
    foreach($lnkFile in (Get-ChildItem $startupPath).Name)
    {
        $sh = New-Object -ComObject WScript.Shell
        $target = $sh.CreateShortcut($startupPath + $lnkFile).TargetPath        $AutorunsPath += New-Object -TypeName PSobject -Property @{ 
                  path = $startupPath
                Source = $target }    }    return $AutorunsPath}