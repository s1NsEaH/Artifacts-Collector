function ShellBags_Parser
{
    param([array]$Bytes)

    $BinaryReader = New-Object IO.BinaryReader (New-Object IO.MemoryStream (, $Bytes) )
    
    $Size = $BinaryReader.ReadInt16()   # The size of the shell item
    $Type = $BinaryReader.ReadByte()    # Class type indicator
    if($Type -eq 0x1f)
    {
        $Sort = $BinaryReader.ReadByte()    # Sort index
        $null = $BinaryReader.ReadBytes(16) # Shell folder identifier
        if($Sort -eq 0x00)
        { $Name = "Internet Explorer" }
        elseif($Sort -eq 0x42)
        { $Name = "Libraries" }
        elseif($Sort -eq 0x44)
        { $Name = "Users" }
        elseif($Sort -eq 0x48)
        { $Name = "My Documents" }
        elseif($Sort -eq 0x50)
        { $Name = "My Computer" }
        elseif($Sort -eq 0x58)
        { $Name = "My Network Places/Network" }
        elseif($Sort -eq 0x60)
        { $Name = "Recycle Bin" }
        elseif($Sort -eq 0x68)
        { $Name = "Internet Explorer" }
        elseif($Sort -eq 0x80)
        { $Name = "My Games" }
        else
        { $Name = "Unknown" }
        
        return $Name
    }
    elseif( $Type -match "3[2-9]|4[0-7]" ) # 0x20 ~ 0x2f
    {
        [String]$Device = ""
        foreach( $idx in 0..($Size - 1) )
        {
            $Temp = [char]$BinaryReader.ReadByte()  # From Null
            if($Temp -ne [byte]0) {
                $Device += $Temp   
            } else {
                break
            }
        }
        return $Device
    }
    elseif( $Type  -match "4[8-9]|5[0-9]|6[0-3]" ) # 0x30 ~ 0x3f
    {
        $null = $BinaryReader.ReadByte()        # Unknown
        $null = $BinaryReader.ReadInt32()       # File Size
        $LastTime = $BinaryReader.ReadInt32()   #Last modification date and time
        $Flag = $BinaryReader.ReadInt16()       # File Flags

        [String]$Name = ""
        foreach( $idx in 0..($Size - 1) )
        {
            $Temp = [char]$BinaryReader.ReadByte()  # From Null
            if($Temp -ne [byte]0) {
                $Name += $Temp   
            } else {
                break
            }
        }
        if( ($BinaryReader.BaseStream.Position % 2) -ne 0 )
        { $null = $BinaryReader.ReadByte() }
        
        #  File entry extension block
        $exSize = $BinaryReader.ReadInt16() # Extension size
        $exVers = $BinaryReader.ReadInt16() # 3 ⇒ Windows XP or 2003,    7 ⇒ Windows Vista (SP0)
                                            # 8 ⇒ Windows 2008, 7, 8.0,  9 ⇒ Windows 8.1, 10
        $exSign = $BinaryReader.ReadInt32() # 0xbeef0004 Extension signature
        if($exSign -eq 0xbeef0004)
        {
            $null     = $BinaryReader.ReadInt32() # Creation date and time
            $LastTime = $BinaryReader.ReadInt32() # Last access date and time
            $null     = $BinaryReader.ReadInt16() # Unknown (version or identifier?)
            if($exVers -ge 7) # If extension version >= 7
            {
                $null = $BinaryReader.ReadInt16() # Unknown
                $null = $BinaryReader.ReadInt64() # File reference
                $null = $BinaryReader.ReadInt64() # Unknown
    
                $LongSize = $BinaryReader.ReadInt16() # Long string size
    
                if($exVers -ge 9) { # If extension version >= 9
                    $null = $BinaryReader.ReadInt32() # Unknown
                }
    
                if($exVers -ge 8) { # If extension version >= 8
                    $null = $BinaryReader.ReadInt32() # Unknown
                }
    
                [string]$LongName = ""
                foreach( $idx in 0..($Size - 1) )
                {
                    $Temp = $BinaryReader.ReadBytes(2)  # From Null
                    if($Temp -ne [byte]0) {
                        $LongName += [Text.Encoding]::Unicode.GetChars($Temp)
                    } else {
                        break
                    }
                } # foreach
            } # if
            if($LongName -ne "")
            {
                return $LongName
            } else {
                return $Name
            } # else
        } # if
    } # elseif
} # function

function preOrder
{
    param([string]$path, [string]$outputPath)
    $Sta = 0; $End = 3;
    while(1)
    {
        $ReadBytes = (Get-ItemProperty $path).MRUListEx[$Sta..$End]
        $Toint = [BitConverter]::ToInt32($ReadBytes, 0)
        if($Toint -eq -1) { return }
 
        $TransName = (ShellBags_Parser (Get-ItemProperty $path).$Toint) + '\'
        
        $oldPath = $outputPath
        $outputPath += $TransName
        
        $RegPath = ((Get-ItemProperty $path).PSPath + '\' + $Toint).replace("Microsoft.PowerShell.Core\","")
        $Global:ParserTable += New-Object -TypeName psobject -Property @{ Source = $RegPath
                                                                            Path = $outputPath
                                                                LastModifiedTime = Get-Item $RegPath | Add-RegKeyMember | %{ $_.LastWriteTime }
                                                                        }
        $Node = $path + '\' + $Toint
        $Global:NodeOrder += $Node
        $Sta = ($End + 1); $End += 4
        preOrder $Node $outputPath
        
        $outputPath = $oldPath
    }
}    

function Get-ShellBags
{
    [array]$Global:NodeOrder = $null; [array]$Global:ParserTable = $null
    $Rootpath = "Registry::HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\BagMRU"
    $initPath = ""
    preOrder $Rootpath $initPath
    return $Global:ParserTable | Select-Object Path, LastModifiedTime, Source
}