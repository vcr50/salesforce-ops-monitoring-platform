$dir = "d:\TomCodeX Inc\SEOMP\website"

# Replace small 20px logo + "TomCodeX Inc" footer references
$footerOld = '<img src="assets/logo.svg" alt="Logo" style="width: 20px; height: 20px;">'
$footerNew = '<img src="assets/tomcodex-logo.svg" alt="TomCodeX Logo" style="height: 28px; width: auto;">'

# Replace About / Careers signature logo (36-40px)
$sig36Old = '<img src="assets/logo.svg" alt="Tomcodex logo" class="about-sig-logo">'
$sig36New = '<img src="assets/tomcodex-logo.svg" alt="TomCodeX Logo" class="about-sig-logo" style="height:44px; width:auto;">'

$sig40Old = '<img src="assets/logo.svg" alt="Tomcodex" style="width: 36px; height: 36px; flex-shrink: 0;">'
$sig40New = '<img src="assets/tomcodex-logo.svg" alt="TomCodeX" style="height:44px; width:auto; flex-shrink:0;">'

$carSigOld = '<img src="assets/logo.svg" alt="Tomcodex">'
$carSigNew = '<img src="assets/tomcodex-logo.svg" alt="TomCodeX" style="height:40px; width:auto;">'

Get-ChildItem "$dir\*.html" | ForEach-Object {
    $c = [System.IO.File]::ReadAllText($_.FullName)
    $c = $c.Replace($footerOld, $footerNew)
    $c = $c.Replace($sig36Old, $sig36New)
    $c = $c.Replace($sig40Old, $sig40New)
    $c = $c.Replace($carSigOld, $carSigNew)
    [System.IO.File]::WriteAllText($_.FullName, $c)
    Write-Host "Updated: $($_.Name)"
}
Write-Host "Done."
