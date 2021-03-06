function Get-Prefetch
{
    $UnicodeEncoding = [Text.Encoding]::Unicode
    $Prefetch = "$env:WINDIR\Prefetch\"
    [array]$PrefetchTable = $null
    foreach ($PrefetchFile in (Get-ChildItem $Prefetch))
    {
        if($PrefetchFile.Name -match ".*`.pf")
        {
            $FileName = $Prefetch+$PrefetchFile.Name
            $BinaryReader = New-Object IO.BinaryReader (New-Object IO.MemoryStream (,[IO.File]::ReadAllBytes($FileName)))
            $Version = $BinaryReader.ReadInt32()
            $Signature = $BinaryReader.ReadInt32() # SCCA
            if ( ($Version -eq 0x17) -and ($Signature -eq 0x41434353) ) # Windows Vista, Windows 7
            {
                $null = $BinaryReader.BaseStream.Seek(100, [IO.SeekOrigin]::Begin) # Jump to offset of section C
                $FileOffset = $BinaryReader.ReadInt32()
                $FileCount = $BinaryReader.ReadInt32()
                                                    #Decimal
                $null = $BinaryReader.BaseStream.Seek(128, [IO.SeekOrigin]::Begin) # Jump to offset of LatestExecutionTime
                $LatestExecutionTime = [DateTimeOffset]::FromFileTime($BinaryReader.ReadInt64()).DateTime
            
                $null = $BinaryReader.BaseStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                $EndPosition = $FileCount + $BinaryReader.BaseStream.Position
            
                $PrefetchTable += New-Object -TypeName psobject -Property @{ 
                    LastModifiedTime = $LatestExecutionTime 
                                Path = $FileName
                              Source = $Prefetch + $PrefetchFile
                }
                do
                {
                    $JoinString = ""
                    while(1)
                    {
                        $Temp = $UnicodeEncoding.GetString($BinaryReader.ReadBytes(2))
                        if( $Temp -ne "") {
                            $JoinString += $Temp
                        } else {
                            break
                        }
                    }      
                } until ( $EndPosition -eq $BinaryReader.BaseStream.Position )
            }  # if
        } # if
    } # foreach
    $BinaryReader.BaseStream.Dispose()
    return $PrefetchTable
} # function