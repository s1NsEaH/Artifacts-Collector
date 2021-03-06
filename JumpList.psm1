function Get-InitalPosition([int]$offset)
{
    $null = $MemoryScanner.BaseStream.Seek($offset, [IO.SeekOrigin]::Begin)
    return $MemoryScanner.ReadInt32()
}

function Get-BlockOffset([int]$offset)
{
    return ($offset * 512) + 512
}

function Get-ConcatBBATChain([int]$offset)
{
    $null = $MemoryScanner.BaseStream.Seek($offset, [IO.SeekOrigin]::Begin)
    $Lines = 128 # Block size is 0x200, 512byte / 4 = 128;
    [array]$Chain = $null
    while($Lines--)
    {
        $Chain += $MemoryScanner.ReadInt32()
    }
    return $Chain
}
function Get-EntryChain([array]$Chain, [int]$StartBlock)
{
    [array]$EntryChain = $StartBlock
    while(1)
    {
        $StartBlock = $Chain[$StartBlock]
        if( ($StartBlock -eq -2) -or ($StartBlock -eq -1) )
        { return $EntryChain }

        $EntryChain += $StartBlock
    }
}
function Get-Boundary([int]$offset,[array]$AvoidOffset)
{
    $Depth = 0; $Boundary = 900000

    foreach($avoid in $AvoidOffset)
    {
        if($offset -le $avoid)
        {
            $Depth = 1; $Boundary = $avoid
            break
        }
    }
    if( $AvoidOffset -contains ($Boundary + 0x200) )
    {
        $Depth = 2
        if( $AvoidOffset -contains ($Boundary + 0x400) )
        {
            $Depth = 3
        }
    }

    $Result = New-Object -TypeName psobject -Property @{ Boundary = $Boundary
                                                            Depth = $Depth }
    return $Result
}
function Get-PropertyData([int]$offset,[int]$Boundary, [int]$Depth)
{
    function Get-Position([int]$Addoffset,[int]$CalcBoundary, [int]$CalcDepth, [int]$convert)
    {
        if( ($Addoffset -ge $CalcBoundary) -and ($convert -eq 0) )
        {
            $Addoffset += ($CalcDepth * 0x200)
            $convert = 1
        }
        $ResultTable = New-Object -TypeName psobject -Property @{ Addoffset = $Addoffset
                                                                    convert = $convert }
        return $ResultTable
    }

    # Start Lnk File format
    $null = $MemoryScanner.BaseStream.Seek($offset, [IO.SeekOrigin]::Begin)
#   $HeaderLen = $MemoryScanner.ReadInt32()
    $LinkFlags_Offset = 0x14; $AccessTime_Offset = 0x24; $IDListSize_Offset = 0x4C;
    
    $LinkFlags_DATA = Get-Position ($offset + $LinkFlags_Offset) $Boundary $Depth 0
    $AccessTime_DATA = Get-Position ($offset + $AccessTime_Offset) $Boundary $Depth $LinkFlags_DATA.convert
    $IDListSize_DATA = Get-Position ($offset + $IDListSize_Offset) $Boundary $Depth $AccessTime_DATA.convert
    
#    if($HeaderLen -eq 76)
#    {
        $null = $MemoryScanner.BaseStream.Seek($LinkFlags_DATA.Addoffset, [IO.SeekOrigin]::Begin)
        $LinkFlags = $MemoryScanner.ReadInt32()
        
        $null = $MemoryScanner.BaseStream.Seek($AccessTime_DATA.Addoffset, [IO.SeekOrigin]::Begin)
        $Time = [DateTime]::FromFileTime($MemoryScanner.ReadInt64())
        $null = $MemoryScanner.BaseStream.Seek($IDListSize_DATA.Addoffset, [IO.SeekOrigin]::Begin)
        $IDListSize = $MemoryScanner.ReadInt16()
        $CurrentPosition = $MemoryScanner.BaseStream.Position
        
        $IDList_DATA = Get-Position ($CurrentPosition + $IDListSize) $Boundary $Depth $IDListSize_DATA.convert
        $null = $MemoryScanner.BaseStream.Seek($IDList_DATA.Addoffset, [IO.SeekOrigin]::Begin)
        #$LinkInfoFlags_Offset = 0x08
        #$LinkInfoSize = 0x00;
        #$LinkInfo_DATA = Get-Position ($IDList_DATA.Addoffset + $LinkInfoSize) $Boundary $Depth $IDList_DATA.convert
        # LocalBasePath_Offset is away 8bytes from LinkInfoFlags_Offset
        
        $LinkInfoFlags_Offset = 0x08; $LocalBasePath_Offset = 0x08; $DriveType_Offset = 0x10
        $LinkInfoFlags_DATA = Get-Position ($IDList_DATA.Addoffset + $LinkInfoFlags_Offset) $Boundary $Depth $IDList_DATA.convert
        $LocalBasePath_DATA = Get-Position ($LinkInfoFlags_DATA.Addoffset + $LocalBasePath_Offset) $Boundary $Depth $LinkInfoFlags_DATA.convert
        $DriveType_DATA     = Get-Position ($LocalBasePath_DATA.Addoffset + $DriveType_Offset) $Boundary $Depth $LocalBasePath_DATA.convert
        $LinkInfoSize = $MemoryScanner.ReadUInt32()
        
        $null = $MemoryScanner.BaseStream.Seek($LinkInfoFlags_DATA.Addoffset, [IO.SeekOrigin]::Begin)
        $LinkInfoFlags = $MemoryScanner.ReadInt32()

        if($LinkInfoFlags -eq 1)
        {  #$LocalBasePathOffsetUnicode 
            $null = $MemoryScanner.BaseStream.Seek($LocalBasePath_DATA.Addoffset, [IO.SeekOrigin]::Begin)
            $PathOffset = $MemoryScanner.ReadInt32()
            $CurrentPosition = $MemoryScanner.BaseStream.Position
            
            $null = $MemoryScanner.BaseStream.Seek($DriveType_DATA.Addoffset, [IO.SeekOrigin]::Begin)
            $DriveType = $MemoryScanner.ReadInt32()
                                                                      # 0xD Just We assume PathOffset is 0x2D
            $StartPath_DATA = Get-Position ($DriveType_DATA.Addoffset + 0xD) $Boundary $Depth $DriveType_DATA.convert
            
            $PathLen = $LinkInfoSize - ($PathOffset + 2)
            if( ( ($StartPath_DATA.Addoffset + $PathLen) -ge $Boundary ) -and ($StartPath_DATA.convert -eq 0) )
            {
                $RestOfLen = ($StartPath_DATA.Addoffset + $PathLen) - $Boundary
                $Len = $PathLen - $RestOfLen
                
                $null = $MemoryScanner.BaseStream.Seek($StartPath_DATA.Addoffset, [IO.SeekOrigin]::Begin)
                $Str = [Text.Encoding]::ASCII.GetString($MemoryScanner.ReadBytes($Len))
                $CurrentPosition = ($MemoryScanner.BaseStream.Position + 0x200)
                $null = $MemoryScanner.BaseStream.Seek($CurrentPosition, [IO.SeekOrigin]::Begin)
                $Str += [Text.Encoding]::ASCII.GetString($MemoryScanner.ReadBytes($RestOfLen))
            } else {
                $null = $MemoryScanner.BaseStream.Seek($StartPath_DATA.Addoffset, [IO.SeekOrigin]::Begin)
                $Str = [Text.Encoding]::ASCII.GetString($MemoryScanner.ReadBytes($PathLen))
            }
        }
       
        $JumpListTable = New-Object -TypeName psobject -Property @{ LastModifiedTime = $Time
                                                                    Path = $Str
                                                               DriveType = $DriveType 
                                                                  Source = $Global:source }
    return $JumpListTable
}

function Get-Proc
{
    param([string]$path)
    $MemoryScanner = New-Object IO.BinaryReader ( New-Object IO.MemoryStream (, [IO.File]::ReadAllBytes($path)) )
    [string]$MagicID = $MemoryScanner.ReadBytes(8) | % { "{0:x}" -f $_ }

    if($MagicID.ToUpper() -match "D0 CF 11 E0 A1 B1 1A E1")
    {
        #Offset between 0 and 512 byte  (Read int32)
        $BBATCnt_Offset = 0x2C; $RootEntryStartBlock_Offset = 0x30
        $SBATStartBlock_Offset = 0x3C; $SBATCnt_Offset = 0x40
        $BBATChain_Offset_Offset = 0x4C;
        [array]$BBATChain_Offset = $null  # each chain offset
        [array]$BBATTableChain = $null    # All table concat
        [array]$SBATBlock = $null;  [array]$SBATBlockOffset = $null
        [array]$DestBlock = $null;  [array]$DestBlockOffset = $null
    
        $BBATCnt = Get-InitalPosition $BBATCnt_Offset
        $RootEntryStartBlock = Get-InitalPosition $RootEntryStartBlock_Offset
        $SBATStartBlock = Get-InitalPosition $SBATStartBlock_Offset
        $SBATCnt = Get-InitalPosition $SBATCnt_Offset
        if($BBATCnt -gt 109) { Write-Host "Warnning: BBAT Entry more than 109"}
    
        $null = $MemoryScanner.BaseStream.Seek($BBATChain_Offset_Offset, [IO.SeekOrigin]::Begin)
        # Get BBAT Block Chain offset
        while($BBATCnt--)
        { $BBATChain_Offset += Get-BlockOffset $MemoryScanner.ReadInt32() }

        # Concat BBAT Block Chain
        foreach($Chain_offset in $BBATChain_Offset)
        { $BBATTableChain += Get-ConcatBBATChain $Chain_offset }

        # Get each property block
        [array]$PropertyBlock = Get-EntryChain $BBATTableChain $RootEntryStartBlock

        # Get each property offset
        [array]$PropertyBlockOffset = $null
        foreach( $idx in 0..($PropertyBlock.Count - 1) )
        {
            $PropertyBlockOffset += Get-BlockOffset $PropertyBlock[$idx]
        }
 
        # Get each SBAT Block
        $SBATBlock = Get-EntryChain $BBATTableChain $SBATStartBlock
        foreach( $idx in 0..($SBATBlock.Count - 1) )
        {
            $SBATBlockOffset += Get-BlockOffset $SBATBlock[$idx]
        }
 
        # Get each property of data
        $PropertyDataStart_Offset = 0x74; # Before Property block
        [array]$JumpList=$null
        $null = $MemoryScanner.BaseStream.Seek($PropertyBlockOffset[0] + $PropertyDataStart_Offset, [IO.SeekOrigin]::Begin)
        $RootChain = Get-EntryChain $BBATTableChain $MemoryScanner.ReadUInt32()
        $PropertyGap = 0x80;
 
        #Find DestList
        foreach($idx in 0..3) # 512 / 128 = 4
        {
            $offset = $PropertyBlockOffset[0] + ($PropertyGap * $idx)
            $null = $MemoryScanner.BaseStream.Seek($offset, [IO.SeekOrigin]::Begin)
            $DestName = [Text.Encoding]::Unicode.GetString($MemoryScanner.ReadBytes(16))
            if($DestName -match "DestList")
            {
                $null = $MemoryScanner.BaseStream.Seek($offset + $PropertyDataStart_Offset, [IO.SeekOrigin]::Begin)
                $StartBlockofDest = $MemoryScanner.ReadUInt32()
            }
        }
        # Get each DestList Block
        $DestBlock = Get-EntryChain $BBATTableChain $StartBlockofDest
        foreach( $idx in 0..($DestBlock.Count - 1) )
        {
            $DestBlockOffset += Get-BlockOffset $DestBlock[$idx]
        }
 
        # Make avoid block in parsing
        [array]$AvoidOffset = $DestBlockOffset + $SBATBlockOffset + $PropertyBlockOffset + $BBATChain_Offset
        $AvoidOffset = $AvoidOffset | Sort-Object
        
        foreach($LnkOffset in $PropertyBlockOffset)
        {
            foreach($idx in 0..3) # 512 / 128 = 4
            {
                $LnkBlockOffset = $LnkOffset + $PropertyDataStart_Offset + ($PropertyGap * $idx)
                $null = $MemoryScanner.BaseStream.Seek($LnkBlockOffset, [IO.SeekOrigin]::Begin)
                $StartBlockofProperty = $MemoryScanner.ReadUInt32()
                $PropertyBlockSize = $MemoryScanner.ReadUInt32()
                if($PropertyBlockSize -le 0x1000)
                {
                    [int]$Point = (Get-BlockOffset $RootChain[[Math]::Floor($StartBlockofProperty / 8)]) + (($StartBlockofProperty % 8) * 64)
                    $AttachData = Get-Boundary $Point $AvoidOffset
                    $JumpList += Get-PropertyData $Point $AttachData.Boundary $AttachData.Depth
                }
            }
        }
    }
    $MemoryScanner.BaseStream.Dispose()
    return $JumpList
}

function Get-JumpList
{
    $AutoDirPath = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\"
    $AutoDir = Get-ChildItem $AutoDirPath
    foreach($dir in $AutoDir)
    {
        $Global:source = $AutoDirPath + $dir
        Get-Proc ($AutoDirPath + $dir.Name)
    }
}