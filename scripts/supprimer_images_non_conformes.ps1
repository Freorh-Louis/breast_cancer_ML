# Supprime les images qui ne font pas 50 x 50, d'après le rapport CSV (dimensions revérifiées avant suppression).
# Les fichiers illisibles sont conservés. Simulation par défaut ; ajouter -Supprimer pour appliquer.
# Usage : .\supprimer_images_non_conformes.ps1 -RapportCsv non_conformes.csv [-Supprimer]
param(
    [Parameter(Mandatory = $true)]
    [string]$RapportCsv,

    [int]$Largeur = 50,
    [int]$Hauteur = 50,
    [switch]$Supprimer
)

$ErrorActionPreference = "Stop"
$SignaturePng = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)

if (-not (Test-Path -LiteralPath $RapportCsv)) {
    throw "Rapport introuvable : $RapportCsv"
}

# Même lecture d'en-tête PNG que dans compter_dimensions_images.ps1.
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
    $L = ([int]$Octets[16] -shl 24) -bor ([int]$Octets[17] -shl 16) -bor ([int]$Octets[18] -shl 8) -bor [int]$Octets[19]
    $H = ([int]$Octets[20] -shl 24) -bor ([int]$Octets[21] -shl 16) -bor ([int]$Octets[22] -shl 8) -bor [int]$Octets[23]
    return @($L, $H)
}

if ($Supprimer) {
    Write-Host "MODE SUPPRESSION : les images non conformes vont être supprimées." -ForegroundColor Yellow
} else {
    Write-Host "MODE SIMULATION : aucun fichier ne sera supprimé (ajouter -Supprimer pour appliquer)."
}

$Lignes = Import-Csv -LiteralPath $RapportCsv
$Supprimees = 0; $Illisibles = 0; $Absentes = 0; $Conformes = 0

foreach ($Ligne in $Lignes) {
    if (-not (Test-Path -LiteralPath $Ligne.Chemin)) {
        $Absentes++
        continue
    }

    # Nouvelle vérification au moment d'agir.
    $Dim = Get-DimensionsPng -Chemin $Ligne.Chemin
    if ($null -eq $Dim) {
        $Illisibles++
        Write-Host "  [CONSERVÉ] illisible, à vérifier à la main : $($Ligne.Chemin)"
        continue
    }
    if ($Dim[0] -eq $Largeur -and $Dim[1] -eq $Hauteur) {
        $Conformes++
        continue
    }

    if ($Supprimer) {
        Remove-Item -LiteralPath $Ligne.Chemin
    } else {
        Write-Host ("  [SIMULATION] supprimerait : {0} ({1}x{2})" -f $Ligne.Fichier, $Dim[0], $Dim[1])
    }
    $Supprimees++
}

Write-Host ""
if ($Supprimer) {
    Write-Host "Images non conformes supprimées : $Supprimees"
} else {
    Write-Host "Images non conformes à supprimer : $Supprimees (aucune suppression effectuée)"
}
Write-Host "Fichiers illisibles conservés     : $Illisibles"
Write-Host "Redevenus conformes (ignorés)     : $Conformes"
Write-Host "Absents (ignorés)                 : $Absentes"