function Get-MuiCache
{
    $path = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\ShellNoRoam\MUICache"
    [array]$MuiCacheTable = $null
    $OS = Get-WmiObject -Class Win32_OperatingSystem 
    if($OS.Version -like '6.1*') { # Windows 7 / Server 2008 R2
        $path = "Registry::HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
        $Application = (Get-Item $path).Property | Where-Object { $_ -notmatch "LangID" }
        $MuiCacheTable += New-Object -TypeName psobject -Property @{ Path = $Application
                                                                   Source = $path }
    }
    return $MuiCacheTable
}
