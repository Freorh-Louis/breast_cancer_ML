# Supprime les fichiers identiques (taille + SHA-256) au sein de chaque classe, en gardant un exemplaire.
# Simulation par défaut ; ajouter -Supprimer pour appliquer.
# Usage : .\supprimer_doublons_images.ps1 [-Dossier images_regroupees] [-Supprimer]
param(
    [string]$Dossier = "images_regroupees",
    [switch]$Supprimer
)

$ErrorActionPreference = "Stop"
$Classes = @("0", "1")

if ($Supprimer) {
    Write-Host "MODE SUPPRESSION : les doublons vont être supprimés." -ForegroundColor Yellow
} else {
    Write-Host "MODE SIMULATION : aucun fichier ne sera supprimé (ajouter -Supprimer pour appliquer)."
}

$TotalDoublons = 0

foreach ($Classe in $Classes) {
    $DossierClasse = Join-Path $Dossier $Classe
    if (-not (Test-Path -LiteralPath $DossierClasse)) {
        Write-Warning "Dossier absent, ignoré : $DossierClasse"
        continue
    }

    $Fichiers = Get-ChildItem -LiteralPath $DossierClasse -File
    $Doublons = New-Object System.Collections.Generic.List[System.IO.FileInfo]

    # Étape 1 : seules les tailles partagées par plusieurs fichiers sont candidates.
    $GroupesTaille = $Fichiers | Group-Object Length | Where-Object { $_.Count -gt 1 }

    foreach ($GroupeTaille in $GroupesTaille) {
        # Étape 2 : empreinte SHA-256 des candidats.
        $AvecHash = $GroupeTaille.Group | ForEach-Object {
            [PSCustomObject]@{
                Fichier = $_
                Hash    = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
        }
        # Étape 3 : on garde le premier de chaque groupe d'empreintes identiques.
        $AvecHash | Group-Object Hash | Where-Object { $_.Count -gt 1 } | ForEach-Object {
            $Tries = $_.Group | Sort-Object { $_.Fichier.Name }
            $Tries | Select-Object -Skip 1 | ForEach-Object { $Doublons.Add($_.Fichier) }
        }
    }

    Write-Host ""
    Write-Host ("Classe {0} : {1} fichiers, {2} doublons" -f $Classe, $Fichiers.Count, $Doublons.Count)

    foreach ($Doublon in $Doublons) {
        if ($Supprimer) {
            Remove-Item -LiteralPath $Doublon.FullName
        } else {
            Write-Host "  [SIMULATION] supprimerait : $($Doublon.Name)"
        }
    }
    $TotalDoublons += $Doublons.Count
}

Write-Host ""
if ($Supprimer) {
    Write-Host "Doublons supprimés : $TotalDoublons"
} else {
    Write-Host "Doublons détectés : $TotalDoublons (aucune suppression effectuée)"
}