rm:
  #!/usr/bin/env sh
  set -eu
  containers="$(docker ps -a --filter status=exited --filter status=created --filter status=dead --format '{{{{.Names}}	{{{{.ID}}	{{{{.Status}}')"
  if [ -z "$containers" ]; then
    gum style --foreground 3 "No stopped containers."
    exit 0
  fi
  selected="$(printf '%s\n' "$containers" | gum choose --no-limit --selected='*' --height 20 --header "Stopped containers (space toggles, enter confirms)")"
  [ -n "$selected" ]
  printf '%s\n' "$selected" | awk -F'\t' '{ print $1" — "$3 }' | gum style --border rounded --padding "0 1" --foreground 1
  gum confirm "Remove $(printf '%s\n' "$selected" | wc -l | tr -d ' ') container(s)?"
  printf '%s\n' "$selected" | cut -f2 | xargs docker rm

rmi filter="":
  #!/usr/bin/env sh
  set -eu
  filter="{{ filter }}"
  [ -n "$filter" ] || filter="$(gum input --prompt "Image name contains> " --placeholder "e.g. myapp")"
  [ -n "$filter" ]
  images="$(docker images --format '{{{{.Repository}}:{{{{.Tag}}	{{{{.ID}}	{{{{.Size}}' | awk -F'\t' -v f="$filter" 'index(tolower($1), tolower(f))')"
  if [ -z "$images" ]; then
    gum style --foreground 3 "No images match \"$filter\"."
    exit 0
  fi
  selected="$(printf '%s\n' "$images" | gum choose --no-limit --selected='*' --height 20 --header "Images matching \"$filter\" (space toggles, enter confirms)")"
  [ -n "$selected" ]
  printf '%s\n' "$selected" | cut -f1 | gum style --border rounded --padding "0 1" --foreground 1
  gum confirm "Delete $(printf '%s\n' "$selected" | wc -l | tr -d ' ') image(s)?"
  printf '%s\n' "$selected" | awk -F'\t' '{ print ($1 ~ /<none>/) ? $2 : $1 }' | xargs docker rmi
