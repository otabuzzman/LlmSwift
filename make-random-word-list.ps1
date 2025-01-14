# made with Copilot
# usage: ./make-random-word-list.ps1 <number of words> <word> [ <words> ... ]

param (
    [int]$num_words,
    [string[]]$words
)

# Überprüfen, ob genügend Wörter angegeben wurden
if ($words.Length -eq 0) {
    Write-Error "Bitte geben Sie eine Liste von Wörtern als Parameter an."
    exit 1
}

# Zufällige Auswahl der Wörter
$selected_words = @()
for ($i = 0; $i -lt $num_words; $i++) {
    $random_index = Get-Random -Minimum 0 -Maximum $words.Length
    $selected_words += $words[$random_index]
}

# Ausgabe der ausgewählten Wörter durch Leerzeichen getrennt in einer Zeile
Write-Output ($selected_words -join " ")
