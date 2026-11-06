# Run by vhd.sh through powershell.exe, with $distro set ahead of it. Prints
# whether this distro's virtual disk is sparse: sparse, not-sparse or unknown.
#
# WSL keeps one registry key per distro under Lxss, holding its name and the
# folder its .vhdx lives in. The sparse flag is an ordinary NTFS attribute on
# that file, readable without admin rights.

try {
  $lxss = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
  $key = Get-ChildItem $lxss -ErrorAction Stop |
    Where-Object { $_.GetValue('DistributionName') -eq $distro } |
    Select-Object -First 1
  if (-not $key) { 'unknown'; exit }

  $file = $key.GetValue('VhdFileName')
  if (-not $file) { $file = 'ext4.vhdx' }
  $base = $key.GetValue('BasePath') -replace '^\\\\\?\\', ''
  $vhd = Get-Item -LiteralPath (Join-Path $base $file) -ErrorAction Stop

  if ($vhd.Attributes -band [IO.FileAttributes]::SparseFile) { 'sparse' } else { 'not-sparse' }
} catch {
  'unknown'
}
