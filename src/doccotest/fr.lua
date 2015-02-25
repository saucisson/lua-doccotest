return {
  en = {
    ["input-help"    ] = "chemin vers le fichier source",
    ["inputs-help"   ] = "chemins vers les autres fichiers sources",
    ["output-help"   ] = "chemin vers le fichier de sortie",
    ["format-help"   ] = "format de sortie: TAP",
    ["verbose-help"  ] = "mode verbeux",
    ["unknown-format"] = "!{white redbg}Le format de sortie %{format} n'est pas reconnu.",
    ["read-success"  ] = "Le fichier source %{filename} est ouvert en lecture.",
    ["read-failure"  ] = "!{white redbg}Impossible d'ouvrir le fichier source %{filename}, parce que: %{message}.",
    ["write-success" ] = "Le fichier de sortie %{filename} est ouvert en écriture.",
    ["write-failure" ] = "!{white redbg}Impossible d'ouvrir le fichier de sortie %{filename}, parce que: %{message}.",
    ["no-prompt"     ] = "Le code en %{filename}:%{from}--%{to} ne commence pas par un prompt.",
    ["chunk-success" ] = "L'exécution du code en %{filename}:%{from}--%{to} a réussi.",
    ["chunk-failure" ] = "L'exécution du code en %{filename}:%{from}--%{to} a échoué, parce que: %{message}.",
    ["ring-keep"     ] = "Le lua-ring est conservé après l'exécution du code en %{filename}:%{from}--%{to}.",
    ["ring-close"    ] = "Le lua-ring est détruit après l'exécution du code en %{filename}:%{from}--%{to}.",
    ["test-success"  ] = "!{green}Test réussi en %{filename}:%{from}--%{to}.",
    ["test-failure"  ] = "!{red}Test échoué en %{filename}:%{from}--%{to}: %{stdout}.",
    ["tap-done"      ] = "La sortie au format TAP est disponible dans le fichier %{filename}.",
    ["summary"       ] = "%{filename}: !{green}%{successes}!{reset} succès / !{red}%{failures}!{reset} échecs / !{yellow}%{total}!{reset} total.",
  }
}