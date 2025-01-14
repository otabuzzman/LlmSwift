#!/bin/bash

# made with Copilot
# usage: ./make-random-word-list.sh <number of words> <word> [ <words> ... ]

# Überprüfen, ob genügend Parameter angegeben wurden
if [ "$#" -lt 2 ]; then
  echo "Verwendung: $0 <Anzahl der Wörter> <Wort1> <Wort2> ... <WortN>"
  exit 1
fi

# Anzahl der Wörter, die ausgewählt werden sollen
num_words=$1
shift

# Liste der Wörter
words=("$@")

# Zufällige Auswahl der Wörter
selected_words=()
for ((i=0; i<num_words; i++)); do
  random_index=$((RANDOM % ${#words[@]}))
  selected_words+=("${words[$random_index]}")
done

# Ausgabe der ausgewählten Wörter durch Leerzeichen getrennt in einer Zeile
echo "${selected_words[@]}"
