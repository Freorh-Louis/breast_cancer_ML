# Regroupe les images par classe (0 = non-IDC, 1 = IDC) depuis une archive ZIP ou un dossier extrait.
# La source n'est pas modifiée ; un suffixe __1, __2... évite d'écraser un nom déjà présent.
# Usage : .\regrouper_images.ps1 -Source .\archive.zip [-Destination images_regroupees]
param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [string]$Destination = "images_regroupees"
)

$ErrorActionPreference = "Stop"
$Classes = @("0", "1")

if (-not (Test-Path -LiteralPath $Source)) {
    throw "Source introuvable : $Source"
}

# Création des dossiers de destination et mémorisation des noms déjà présents.
# Un HashSet par classe évite d'interroger le disque pour chaque image.
$NomsUtilises = @{}
foreach ($Classe in $Classes) {
    $Dossier = Join-Path $Destination $Classe
    New-Item -ItemType Directory -Force -Path $Dossier | Out-Null
    $Set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    Get-ChildItem -LiteralPath $Dossier -File | ForEach-Object { [void]$Set.Add($_.Name) }
    $NomsUtilises[$Classe] = $Set
}

# Renvoie un nom libre dans la classe : nom.png, puis nom__1.png, nom__2.png...
function Get-NomUnique {
    param([string]$Classe, [string]$Nom)
    $Set = $NomsUtilises[$Classe]
    $Candidat = $Nom
    $Base = [System.IO.Path]::GetFileNameWithoutExtension($Nom)
    $Ext = [System.IO.Path]::GetExtension($Nom)
    $i = 1
    while ($Set.Contains($Candidat)) {
        $Candidat = "{0}__{1}{2}" -f $Base, $i, $Ext
        $i++
    }
    [void]$Set.Add($Candidat)
    return $Candidat
}

$Compteurs = @{ "0" = 0; "1" = 0 }
$Renommes = 0

if ((Get-Item -LiteralPath $Source).PSIsContainer) {
    # --- Cas 1 : dossier déjà extrait ---
    Write-Host "Lecture du dossier $Source ..."
    Get-ChildItem -LiteralPath $Source -Recurse -File -Filter *.png |
        Where-Object { $Classes -contains $_.Directory.Name } |
        ForEach-Object {
            $Classe = $_.Directory.Name
            $Nom = Get-NomUnique -Classe $Classe -Nom $_.Name
            if ($Nom -ne $_.Name) { $Renommes++ }
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path (Join-Path $Destination $Classe) $Nom)
            $Compteurs[$Classe]++
        }
}
else {
    # --- Cas 2 : archive ZIP, lue sans extraction complète ---
    Write-Host "Lecture de l'archive $Source ..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Source).Path)
    try {
        foreach ($Entree in $Zip.Entries) {
            # Les entrées de type dossier ont un nom vide.
            if (-not $Entree.Name -or -not $Entree.Name.EndsWith(".png", [StringComparison]::OrdinalIgnoreCase)) { continue }

            # Le dossier parent de l'image indique la classe : .../<patient>/<classe>/<image>.png
            $Parties = $Entree.FullName -split "[\\/]"
            if ($Parties.Count -lt 2) { continue }
            $Classe = $Parties[$Parties.Count - 2]
            if ($Classes -notcontains $Classe) { continue }

            $Nom = Get-NomUnique -Classe $Classe -Nom $Entree.Name
            if ($Nom -ne $Entree.Name) { $Renommes++ }
            $Cible = Join-Path (Join-Path $Destination $Classe) $Nom
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($Entree, $Cible, $false)
            $Compteurs[$Classe]++
        }
    }
    finally {
        $Zip.Dispose()
    }
}

Write-Host ""
Write-Host "Regroupement terminé dans : $Destination"
Write-Host ("  Classe 0 (non-IDC) : {0} images" -f $Compteurs["0"])
Write-Host ("  Classe 1 (IDC)     : {0} images" -f $Compteurs["1"])
Write-Host ("  Fichiers renommés avec suffixe (nom déjà présent) : {0}" -f $Renommes)