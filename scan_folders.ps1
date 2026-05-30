$docExt = @('.doc','.docx','.xls','.xlsx','.ppt','.pptx','.pdf','.txt','.csv','.rtf','.odt','.jpg','.jpeg','.png','.psd','.ai','.mp4','.fig','.cdr','.zip','.rar')
$skip = '\\node_modules\\|\\\.git\\|\\build\\|\\\.venv\\|\\vendor\\|\\\.dart_tool\\|\\steamapps\\'
function Report($base) {
  if (-not (Test-Path $base)) { return }
  "===== $base ====="
  Get-ChildItem $base -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $files = Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $docExt -contains $_.Extension.ToLower() -and $_.FullName -notmatch $skip }
    $sum = ($files | Measure-Object -Property Length -Sum).Sum
    if ($files.Count -gt 0) { [PSCustomObject]@{ MB=[math]::Round($sum/1MB,1); Files=$files.Count; Folder=$_.Name } }
  } | Sort-Object MB -Descending | Format-Table -AutoSize
}
Report 'C:\Users\riki\Documents'