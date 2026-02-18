hello-world:
  echo 'Hello World!'

gcloud-switch-profile:
  #!/usr/bin/env sh
  configs="$(gcloud config configurations list --format='get(name)')"
  selected_config="$(echo "$configs" | gum choose --header "Choose a Google Cloud configuration")"
  gcloud config configurations activate "$selected_config"