$docExt = @('.doc','.docx','.xls','.xlsx','.ppt','.pptx','.pdf','.txt','.csv','.rtf','.odt','.md','.jpg','.jpeg','.png','.gif','.bmp','.svg','.psd','.ai','.mp4','.mp3','.wav','.fig','.cdr')
$skip = '\\node_modules\\|\\\.git\\|\\build\\|\\\.venv\\|\\vendor\\|\\\.dart_tool\\|\\steamapps\\|\\Epic Games\\|\\HoYoPlay\\|\\Zenless'
$roots = @('C:\Users\riki\Documents','C:\Users\riki\Downloads','C:\Users\riki\OneDrive','D:\Download')
foreach ($r in $roots) {
  if (Test-Path $r) {
    $files = Get-ChildItem $r -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $docExt -contains $_.Extension.ToLower() -and $_.FullName -notmatch $skip }
    $sum = ($files | Measure-Object -Property Length -Sum).Sum
    "{0,-34} {1,7} dokumen  {2,9:N1} MB" -f $r, $files.Count, ($sum/1MB)
  } else { "{0,-34} (tidak ada)" -f $r }
}