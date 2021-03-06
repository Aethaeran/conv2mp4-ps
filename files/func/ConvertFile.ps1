# Master Encoding function
Function ConvertFile {
    param
    (
        [Parameter(Position = 0, mandatory = $True)]
        [ValidateSet("Simple", "Audio", "Video", "Both", "Handbrake")]
        [String]$ConvertType,
        [Switch]$KeepSubs
    )

    $ffmpeg = Join-Path $cfg.fmmpeg_bin_dir "ffmpeg.exe"
    $handbrake = Join-Path $cfg.handbrakecli_bin_dir "HandBrakeCLI.exe"

    If ($ConvertType -eq "Handbrake") {
        # Handbrake CLI: https://trac.handbrake.fr/wiki/CLIGuide#presets
        # Handbrake arguments
        $hbArgs = @()
        $hbArgs += "-i " #Flag to designate input file
        $hbArgs += "`"$sourceFile`"" #Input file
        $hbArgs += "-o " #Flag to designate output file
        $hbArgs += "`"$targetFile`"" #Output file
        $hbArgs += "-f " #Format flag
        $hbArgs += "mp4 " #Format value
        $hbArgs += "-a " #Audio channel flag
        $hbArgs += "1,2,3,4,5,6,7,8,9,10 " #Audio channels to scan
        If ($KeepSubs) {
            $hbArgs += "--subtitle " #Subtitle channel flag
            $hbArgs += "scan,1,2,3,4,5,6,7,8,9,10 " #Subtitle channels to scan
        }
        $hbArgs += "-e " #Output video codec flag
        $hbArgs += "x264 " #Output using x264
        $hbArgs += "--encoder-preset " #Flag to set encode speed preset
        $hbArgs += "slow " #Encode speed preset
        $hbArgs += "--encoder-profile " #Flag to set encode quality preset
        $hbArgs += "high " #Encode quality preset
        $hbArgs += "--encoder-level " #Profile version to use for encoding
        $hbArgs += "4.1 " #Encode profile value
        $hbArgs += "-q " #Equivalent to CRF in ffmpeg
        $hbArgs += "18 " #CFR value
        $hbArgs += "-E " #Flag to set audio codec
        $hbArgs += "aac " #Use AAC as audio codec
        $hbArgs += "--audio-copy-mask " #Flag to set permitted audio codecs for copying
        $hbArgs += "aac " #Set only AAC as allowed for copying
        $hbArgs += "--verbose=1 " #Flag to set logging level
        $hbArgs += "--decomb " #Flag to set deinterlace video
        $hbArgs += "--loose-anamorphic " #Keep aspect ratio as close as possible to the source videos
        $hbArgs += "--modulus " #Flag to set storage width modulus
        $hbArgs += "2" #Storage width modulus value

        $hbCMD = cmd.exe /c "`"$handbrake`" $hbArgs"
        # Begin Handbrake operation
        Try {
            $hbCMD
            Log "$($time.Invoke()) Handbrake finished."
        }
        Catch {
            Log "$($time.Invoke()) ERROR: Handbrake has encountered an error."
            Log $_
        }
    }
    Else {
        # ffmpeg arguments
        $ffArgs = @()
        $ffArgs += "-n " #Do not overwrite output files, and exit immediately if a specified output file already exists.
        $ffArgs += "-fflags " #Allows setting of formal flags
        $ffArgs += "+genpts " #Suppresses pointer warning messages
        $ffArgs += "-i " #Flag to designate input file
        $ffArgs += "`"$sourceFile`" " #Input file
        $ffArgs += "-threads " #Flag to set maximum number of threads (CPU) to use
        $ffArgs += "6 " #Maximum number of threads (CPU) to use
        $ffArgs += "-movflags"
        $ffArgs += "+faststart"

        If ($cfg.use_set_metadata_title){
            $remove= $title | Select-String -Pattern '^(.*?)(19|20)[0-9]{2}(.*$)'  | ForEach-Object { "$($_.matches.groups[3])" }
            $title = $title -replace "$remove",''
            $title = $title -replace '\W',' '
            $title = $title -replace '(\d{4})$', '($1)';

            $ffArgs += "-metadata " #Flag to specify key/value pairs for encoding metadata
            $ffArgs += "title=`"$title`" " #Use $title variable as metadata 'Title'
        }

        $ffArgs += "-map " #Flag to use channel mapping
        $ffArgs += "0 " #Channel to map (0 is default)
        $ffArgs += "-c:v " #Video codec flag

        #If doing simple or only Audio then just copy video
        If ($ConvertType -eq "Simple" -or $ConvertType -eq "Audio") {
            $ffArgs += "copy " #Copy input file codec settings
        }

        If ($ConvertType -eq "Video" -or $ConvertType -eq "Both") {
            $ffArgs += "libx264 " #Use x264 video codec
            $ffArgs += "-preset " #Video quality preset flag
            $ffArgs += "medium " #Video quality preset
            $ffArgs += "-crf " #Constant rate factor flag
            $ffArgs += "18 " #CRF value
        }

        $ffArgs += "-c:a " #Audio codec flag

        If ($ConvertType -eq "Simple" -or $ConvertType -eq "Video") {
            $ffArgs += "copy " #Copy input file codec settings
        }

        If ($ConvertType -eq "Audio" -or $ConvertType -eq "Both") {
            $ffArgs += "aac " #Use AAC audio codec
        }

        If ($KeepSubs) {
            $ffArgs += "-c:s " #Subtitle codec flag
            $ffArgs += "mov_text " #Name of subtitle channel after export
        }
        Else {
            $ffArgs += "-sn " #Option to remove any existing subtitles
        }
        $ffArgs += "`"$targetFile`"" #Output file

        $ffCMD = cmd.exe /c "$ffmpeg $ffArgs"

        # Begin ffmpeg operation
        $ffCMD
        Write-Output "$($time.Invoke()) ffmpeg completed"
    }
}