switch-context:
  #!/usr/bin/env sh
  contexts="$(kubectl config get-contexts -o name)"
  selected_context="$(echo "$contexts" | gum choose --header "Choose a Kubernetes context")"
  [ -n "$selected_context" ]
  kubectl config use-context "$selected_context"
