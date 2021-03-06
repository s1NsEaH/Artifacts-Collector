function Get-Persisted
{
    # 이 프로그램이 제대로 설치되었습니다
    $PersistedReg = @("Registry::HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant", "Registry::HKLM\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant")
    [array]$PersistedTable = $null
    foreach($Reg in $PersistedReg)
    {
        if (Test-Path $Reg)
        {
            foreach($Property in (Get-ChildItem $Reg).Property)
            {
                $PersistedTable += New-Object -TypeName psobject -Property @{ Path = $Property
                                                                              Source = $Reg }
            }
        }
    }
    return $PersistedTable
}

function Get-Layers
{
    # 호환성 문제에 대한 해결책으로 '호환 모드', '설정', 권한 수준' 등이 설정된 경우
    [array]$LayerReg = @("Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers", "Registry::HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers")
    [array]$LayersTable = $null
    $User = "All Users"
    foreach($Reg in $LayerReg)
    {
        if (Test-Path $Reg)
        {
            if ($Reg -match "HKCU") { $User = "Current Users" }
            $Path = (Get-Item $Reg).Property 
            foreach($FilePath in $Path)
            {
                $LayersTable += New-Object -TypeName psobject -Property @{ 
                    Path = $FilePath
                    User = $User
                    Source = $Reg
                    WindowsVersion = (Get-ItemProperty $Reg).$FilePath
                }
            }
        }
    }
    return $LayersTable
}