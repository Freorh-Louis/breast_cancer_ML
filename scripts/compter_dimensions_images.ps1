# Vérifie que les images font 50 x 50 (lecture de l'en-tête PNG) et repère les fichiers illisibles.
# Avec -RapportCsv, exporte la liste des images non conformes.
# Usage : .\compter_dimensions_images.ps1 [-Dossier images_regroupees] [-RapportCsv non_conformes.csv]
param(
    [string]$Dossier = "images_regroupees",
    [int]$Largeur = 50,
    [int]$Hauteur = 50,
    [string]$RapportCsv
)

$ErrorActionPreference = "Stop"
$Classes = @("0", "1")
$SignaturePng = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)

# Lit largeur et hauteur dans l'en-tête PNG.
# Structure : signature (8 octets) | longueur (4) | "IHDR" (4) | largeur (4) | hauteur (4)
# Renvoie $null si le fichier n'est pas un PNG lisible.
function Get-DimensionsPng {
    param([string]$Chemin)
    try {
        $Flux = [System.IO.File]::OpenRead($Chemin)
        try {
            $Octets = New-Object byte[] 24
            $Lus = $Flux.Read($Octets, 0, 24)
        } finally {
            $Flux.Dispose()
        }
    } catch {
        return $null
    }
    if ($Lus -lt 24) { return $null }
    for ($i = 0; $i -lt 8; $i++) {
        if ($Octets[$i] -ne $SignaturePng[$i]) { return $null }
    }
    if ([System.Text.Encoding]::ASCII.GetString($Octets, 12, 4) -ne "IHDR") { return $null }

    # Entiers stockés en big-endian (octet de poids fort en premier).
    $L = ([int]$Octets[16] -shl 24) -bor ([int]$Octets[17] -shl 16) -bor ([int]$Octets[18] -shl 8) -bor [int]$Octets[19]
    $H = ([int]$Octets[20] -shl 24) -bor ([int]$Octets[21] -shl 16) -bor ([int]$Octets[22] -shl 8) -bor [int]$Octets[23]
    return @($L, $H)
}

$NonConformes = New-Object System.Collections.Generic.List[object]
$RepartitionDimensions = @{}

foreach ($Classe in $Classes) {
    $DossierClasse = Join-Path $Dossier $Classe
    if (-not (Test-Path -LiteralPath $DossierClasse)) {
        Write-Warning "Dossier absent, ignoré : $DossierClasse"
        continue
    }

    $Conformes = 0; $Differentes = 0; $Illisibles = 0

    Get-ChildItem -LiteralPath $DossierClasse -File | ForEach-Object {
        $Dim = Get-DimensionsPng -Chemin $_.FullName
        if ($null -eq $Dim) {
            $Illisibles++
            $NonConformes.Add([PSCustomObject]@{
                Classe = $Classe; Fichier = $_.Name; Chemin = $_.FullName
                Largeur = ""; Hauteur = ""; Statut = "illisible"
            })
            return
        }

        $Cle = "{0}x{1}" -f $Dim[0], $Dim[1]
        if ($RepartitionDimensions.ContainsKey($Cle)) { $RepartitionDimensions[$Cle]++ } else { $RepartitionDimensions[$Cle] = 1 }

        if ($Dim[0] -eq $Largeur -and $Dim[1] -eq $Hauteur) {
            $Conformes++
        } else {
            $Differentes++
            $NonConformes.Add([PSCustomObject]@{
                Classe = $Classe; Fichier = $_.Name; Chemin = $_.FullName
                Largeur = $Dim[0]; Hauteur = $Dim[1]; Statut = "dimensions_differentes"
            })
        }
    }

    Write-Host ""
    Write-Host ("Classe {0} : {1} conformes ({2}x{3}), {4} de dimensions différentes, {5} illisibles" -f `
        $Classe, $Conformes, $Largeur, $Hauteur, $Differentes, $Illisibles)
}

Write-Host ""
Write-Host "Dimensions rencontrées (toutes classes) :"
$RepartitionDimensions.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15 | ForEach-Object {
    Write-Host ("  {0,-10} {1}" -f $_.Key, $_.Value)
}

if ($RapportCsv) {
    $NonConformes | Export-Csv -LiteralPath $RapportCsv -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host ("Rapport exporté : {0} ({1} images non conformes)" -f $RapportCsv, $NonConformes.Count)
}