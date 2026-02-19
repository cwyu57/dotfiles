hello-world:
  echo 'Hello World!'

gcloud-switch-profile:
  #!/usr/bin/env sh
  configs="$(gcloud config configurations list --format='get(name)')"
  selected_config="$(echo "$configs" | gum choose --header "Choose a Google Cloud configuration")"
  gcloud config configurations activate "$selected_config"

gcloud-config-ssh: gcloud-switch-profile
  #!/usr/bin/env sh
  profile="$(gum input --prompt "SSH profile> ")"
  [ -n "$profile" ]
  gcloud compute config-ssh --ssh-key-file="$HOME/.ssh/${profile}-google-compute-engine" --ssh-config-file="$HOME/.ssh/config.d/${profile}"

gcloud-config-ssh-remove: gcloud-switch-profile
  #!/usr/bin/env sh
  profile="$(gum input --prompt "SSH profile> ")"
  [ -n "$profile" ]
  gcloud compute config-ssh --remove --ssh-key-file="$HOME/.ssh/${profile}-google-compute-engine" --ssh-config-file="$HOME/.ssh/config.d/${profile}"
