$root = "$env:USERPROFILE\Downloads\BrainrotGame"

$files = Get-ChildItem -Path $root -Recurse -Include *.rbxmx,*.rbxlx

foreach ($file in $files) {
    $path = $file.FullName
    $text = Get-Content -Path $path -Raw

    $original = $text

    # Empty direct Content tag
    $text = [regex]::Replace(
        $text,
        '<Content name="([^"]+)">\s*</Content>',
        '<Content name="$1"><null></null></Content>'
    )

    # Empty URL content
    $text = [regex]::Replace(
        $text,
        '<Content name="([^"]+)">\s*<url>\s*</url>\s*</Content>',
        '<Content name="$1"><null></null></Content>'
    )

    # Empty hash content
    $text = [regex]::Replace(
        $text,
        '<Content name="([^"]+)">\s*<hash>\s*</hash>\s*</Content>',
        '<Content name="$1"><null></null></Content>'
    )

    # Empty binary content
    $text = [regex]::Replace(
        $text,
        '<Content name="([^"]+)">\s*<binary>\s*</binary>\s*</Content>',
        '<Content name="$1"><null></null></Content>'
    )

    if ($text -ne $original) {
        Set-Content -Path $path -Value $text -Encoding UTF8
        Write-Host "Fixed:" $path
    }
}

Write-Host "Done fixing empty Content values."