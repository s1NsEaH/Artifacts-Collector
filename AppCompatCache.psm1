function Get-AppCompatCache {
   
    $OS = Get-WmiObject -Class Win32_OperatingSystem 
    
    if ($OS.Version -like "5.1*") { 
        $RegPath = "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatibility"
    } else {
        $RegPath = "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache"
    }
    $OSArchitecture = $OS.OSArchitecture
    $ASCIIEncoding = [Text.Encoding]::ASCII
    $UnicodeEncoding = [Text.Encoding]::Unicode
    $AppCompatData = (Get-ItemProperty $RegPath).AppCompatCache
    $BinaryReader = New-Object IO.BinaryReader (New-Object IO.MemoryStream (,$AppCompatData))
    [array]$DataArray = $null
    
    switch ($OS.Version) {
        { $_ -like '10.*' } { # Windows 10
            $null = $BinaryReader.BaseStream.Seek(48, [IO.SeekOrigin]::Begin)
            # check for magic
            if ($ASCIIEncoding.GetString($BinaryReader.ReadBytes(4)) -ne '10ts')
            { 
                $null = $BinaryReader.BaseStream.Seek(52, [IO.SeekOrigin]::Begin) # offset shifted in creators update
                if ($ASCIIEncoding.GetString($BinaryReader.ReadBytes(4)) -ne '10ts') { throw 'Not Windows 10' }
            }

            do { # parse entries
                $null = $BinaryReader.BaseStream.Seek(8, [IO.SeekOrigin]::Current) # padding between entries
                $Path = $UnicodeEncoding.GetString($BinaryReader.ReadBytes($BinaryReader.ReadUInt16()))
                $LastModifiedTime = [DateTimeOffset]::FromFileTime($BinaryReader.ReadInt64()).DateTime
                $null = $BinaryReader.ReadBytes($BinaryReader.ReadInt32()) # skip some bytes

                $DataArray += New-Object -TypeName psobject -Property @{
                    Path = $Path
                    LastModifiedTime = $LastModifiedTime.DateTime
                    Source = $RegPath
                }
            } until ([Text.encoding]::ASCII.GetString($BinaryReader.ReadBytes(4)) -ne '10ts')
        }

        { $_ -like '6.3*' } { # Windows 8.1 / Server 2012 R2

            $null = $BinaryReader.BaseStream.Seek(128, [IO.SeekOrigin]::Begin)

            # check for magic
            if ($ASCIIEncoding.GetString($BinaryReader.ReadBytes(4)) -ne '10ts') { throw 'Not windows 8.1/2012r2' }
            
            do { # parse entries
                $null = $BinaryReader.BaseStream.Seek(8, [IO.SeekOrigin]::Current) # padding & datasize
                $Path = $UnicodeEncoding.GetString($BinaryReader.ReadBytes($BinaryReader.ReadUInt16()))
                $null = $BinaryReader.ReadBytes(10) # skip insertion/shim flags & padding
                $LastModifiedTime = [DateTimeOffset]::FromFileTime($BinaryReader.ReadInt64()).DateTime
                $null = $BinaryReader.ReadBytes($BinaryReader.ReadInt32()) # skip some bytes

                $DataArray += New-Object -TypeName psobject -Property @{
                    Path = $Path
                    LastModifiedTime = $LastModifiedTime.DateTime
                    Source = $RegPath
                }
            } until ($ASCIIEncoding.GetString($BinaryReader.ReadBytes(4)) -ne '10ts')
        }

        { $_ -like '6.2*' } { # Windows 8.0 / Server 2012

            # check for magic
            $null = $BinaryReader.BaseStream.Seek(128, [IO.SeekOrigin]::Begin)
            if ($ASCIIEncoding.GetString($BinaryReader.ReadBytes(4)) -ne '00ts') { throw 'Not Windows 8/2012' }

            do { # parse entries
                $null = $BinaryReader.BaseStream.Seek(8, [IO.SeekOrigin]::Current) # padding & datasize
                $Path = $UnicodeEncoding.GetString($BinaryReader.ReadBytes($BinaryReader.ReadUInt16()))
                $null = $BinaryReader.BaseStream.Seek(10, [IO.SeekOrigin]::Current) # skip insertion/shim flags & padding
                $LastModifiedTime = [DateTimeOffset]::FromFileTime($BinaryReader.ReadInt64()).DateTime
                $null = $BinaryReader.ReadBytes($BinaryReader.ReadInt32()) # skip some bytes

                $DataArray += New-Object -TypeName psobject -Property @{
                   Path = $Path
                   LastModifiedTime = $LastModifiedTime.DateTime
                   Source = $RegPath
                }
            } until ($ASCIIEncoding.GetString($BinaryReader.ReadBytes(4)) -ne '00ts')
        }
        
        { $_ -like '6.1*' } { # Windows 7 / Server 2008 R2
            
            # check for magic
            if ([BitConverter]::ToString($BinaryReader.ReadBytes(4)[3..0]) -ne 'BA-DC-0F-EE') { throw 'Not Windows 7/2008R2'}
            
            $NumberOfEntries = $BinaryReader.ReadInt32()
            $null = $BinaryReader.BaseStream.Seek(128, [IO.SeekOrigin]::Begin) # skip padding

            if ($OSArchitecture -eq '32-bit') {
                do {
                    $EntryPosition++
                    
                    $PathSize = $BinaryReader.ReadUInt16()
                    $null = $BinaryReader.ReadUInt16() # MaxPathSize
                    $PathOffset = $BinaryReader.ReadInt32()
                    $LastModifiedTime = [DateTimeOffset]::FromFileTime($BinaryReader.ReadInt64()).DateTime
                    
                    $null = $BinaryReader.BaseStream.Seek(16, [IO.SeekOrigin]::Current)
                    $Position = $BinaryReader.BaseStream.Position
                    
                    $null = $BinaryReader.BaseStream.Seek($PathOffset+8, [IO.SeekOrigin]::Begin)
                    $Path = $UnicodeEncoding.GetString($BinaryReader.ReadBytes($PathSize-8))
                    
                    $null = $BinaryReader.BaseStream.Seek($Position, [IO.SeekOrigin]::Begin)
                    
                    $DataArray += New-Object -TypeName psobject -Property @{
                        Path = $Path
                        LastModifiedTime = $LastModifiedTime.DateTime
                        Source = $RegPath
                    }
                } until ($EntryPosition -eq $NumberOfEntries)
            }

            else { # 64-bit
                do {
                    $EntryPosition++

                    $PathSize = $BinaryReader.ReadUInt16()
                    # Padding
                    $null = $BinaryReader.BaseStream.Seek(6, [IO.SeekOrigin]::Current)
                    
                    $PathOffset = $BinaryReader.ReadInt64()
                    $LastModifiedTime = [DateTimeOffset]::FromFileTime($BinaryReader.ReadInt64()).DateTime
                    
                    $null = $BinaryReader.BaseStream.Seek(24, [IO.SeekOrigin]::Current)
                    $Position = $BinaryReader.BaseStream.Position
                    
                    $null = $BinaryReader.BaseStream.Seek($PathOffset, [IO.SeekOrigin]::Begin)
                    $Path = $UnicodeEncoding.GetString($BinaryReader.ReadBytes($PathSize))
                    $null = $BinaryReader.BaseStream.Seek($Position, [IO.SeekOrigin]::Begin)
                    
                    $DataArray += New-Object -TypeName psobject -Property @{
                        Path = $Path
                        LastModifiedTime = $LastModifiedTime.DateTime
                        Source = $RegPath
                    }

                } until ($EntryPosition -eq $NumberOfEntries)
            }
        }
    }
    $BinaryReader.BaseStream.Dispose()
    return $DataArray
}