function Get-RecentFileCache
{
    $fileCacheP = "$env:WINDIR\AppCompat\Programs\RecentFileCache.bcf"
    [array]$RecentCacheTable = $null
    if(Test-Path $fileCacheP)
    {
        $RecentFileCache = [IO.File]::ReadAllBytes($fileCacheP)
        $BinaryReader = New-Object IO.BinaryReader (New-Object IO.MemoryStream (,$RecentFileCache))
        $null = $BinaryReader.BaseStream.Seek(20, [IO.SeekOrigin]::Begin) # skip paddin
        do {
            $PathSize = $BinaryReader.ReadUInt32()
            $Path = [Text.Encoding]::Unicode.GetString($BinaryReader.ReadBytes($PathSize*2))
            $null = $BinaryReader.ReadUInt16()
            $RecentCacheTable += New-Object -TypeName psobject -Property @{ Path = $Path
                                                                          Source = $fileCacheP  }
        } until ($RecentFileCache.Count -eq $BinaryReader.BaseStream.Position)
        $BinaryReader.BaseStream.Dispose()
        return $RecentCacheTable
    } else {
        return $RecentCacheTable
    }
}