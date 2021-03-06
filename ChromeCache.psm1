function Get-ChromeCache
{
    $ChromeCachePath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Cache\"
    if(Test-Path $ChromeCachePath)
    {
        $Default_Path = "C:\IndexFile\Chrome\Cache\"
        if(!(Test-Path $Default_Path)) { cmd /c mkdir $Default_Path }
#        $Version = (Get-ItemProperty $ChromeReg).Version
#        if(57 -le $Version.split('`.')[0]) # Compare version
#        {
            $dataUnit = @(0x24,0x100,0x400,0x1000,0x4000); $cnt = 0
            $ReadInt64 = 0x7; $ReadInt32 = 0x3; $ReadInt16 = 0x1; $JumpToURL = 0x60; $urlRecordUnit = 0x18; $JumpTolength = 0x20; $RestOf = ($dataUnit[0] - $urlRecordUnit) ;
            $BaseOffset = 0x2000 # Offset is start by each 0x24 unit from 0x2000 
        
            $CacheName = Get-ChildItem $ChromeCachePath | Where-Object { $_ -match "data*" }
        
            [array]$DataIndex = @()
            [array]$ConnectedURL = $null
            foreach($DataFiles in $CacheName)
            {
                $SourceFile = $ChromeCachePath + $DataFiles
                $CopyFile = $Default_Path + $DataFiles
                Copy-Item $SourceFile $CopyFile -Force
                $DataIndex += New-Object -TypeName psobject -Property @{
                    File = $DataFiles
                    Binary = [IO.File]::ReadAllBytes($CopyFile)
                    DataUnit = $dataUnit[$cnt]
                }
                $cnt++
            }           
                [array]$URL = $null
                $BinaryReader = New-Object IO.BinaryReader (New-Object IO.MemoryStream (,$DataIndex[0].Binary))
                                                # Decimal
                $null = $BinaryReader.BaseStream.Seek($BaseOffset, [IO.SeekOrigin]::Begin)
    #           $LatestExecutionTime = [DateTimeOffset]::FromFileTime($BinaryReader.ReadInt64()).DateTime
                do
                { # Investigate Data_0 file
                $null = $BinaryReader.BaseStream.Seek($urlRecordUnit, [IO.SeekOrigin]::Current) # Seek url record
                
                $urlRecordOffset = $BinaryReader.ReadUInt16() # Get block of index 2bytes
                $FilePosition = $BinaryReader.ReadByte() # Get file of index byte
            
                $null = $BinaryReader.BaseStream.Seek($RestOf - $ReadInt32, [IO.SeekOrigin]::Current) # Keep going next data
                # $FilePosition 왜 1, 0밖에 안나올까?
          
                    if($urlRecordOffset -ne 0) {
                        switch ([int]$FilePosition) {
                            { $_ -eq 0x1 } {
                            # Investigate Data_1 file
                            $RecordOffset = [int]($urlRecordOffset * $DataIndex[1].DataUnit) + $BaseOffset
                            $urlLengthOffset = $RecordOffset + $JumpTolength # Get offset of url length
                            $urlOffset = $RecordOffset + $JumpToURL # Get offset of url
    
                            $TempLength = $DataIndex[1].Binary[$urlLengthOffset..($urlLengthOffset+$ReadInt32)] | % { "{0:x}" -f $_ }
                            [Array]::Reverse($TempLength)
                            [int]$urlLength = "0x$($TempLength -join '')"
                                if($DataIndex[1].Binary[$urlOffset] -ne 0) {
                                    $URL += [Text.encoding]::ASCII.GetString($DataIndex[1].Binary[$urlOffset..($urlOffset+$urlLength)])
                                }
                            } 
                        }# switch
                    }# if
                }# do
            until ($BinaryReader.BaseStream.Position -ge $DataIndex[0].Binary.count)
            $BinaryReader.BaseStream.Dispose()
#        }#if
    }#if
    return $URL
} # function