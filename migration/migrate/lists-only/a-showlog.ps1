$input = Import-Csv "./log/20199005-Werkomgeving-ERROR.csv" #-Header "Status" 

$input | ForEach-Object {
    if($_.Status -eq "Error") 
    {
        Write-Host "[$($_.Title)]" -NoNewline -ForegroundColor Magenta
        Write-Host $_.Details -ForegroundColor Red

    }
    if($_.Status -eq "Warning") 
    {
        Write-Host "[$($_.Title)]" -NoNewline -ForegroundColor Magenta
        Write-Host $_.Details -ForegroundColor Yellow
    }

}