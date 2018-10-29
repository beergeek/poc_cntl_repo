#!/bin/bash

eval "$(rbenv init -)"
rbenv global
shopt -s globstar
 
for f in site/profile/**/**pp; do
   [[ $f =~ plans/ ]] && continue
 
   if puppet parser validate "$f"; then
      echo "SUCCESS: $f"
   else
      echo "FAILED: $f"
      failures+=("$f")
   fi
done
 
for f in site/role/**/**pp; do
   [[ $f =~ plans/ ]] && continue
 
   if puppet parser validate "$f"; then
      echo "SUCCESS: $f"
   else
      echo "FAILED: $f"
      failures+=("$f")
   fi
done
 
if (( ${#failures[@]} > 0 )); then
   echo "Syntax validation on the Control Repo has failed in the following manifests:"
   echo -e "\t ${failures[@]}"
   exit 1
else
   echo "Syntax validation on the Control Repo has succeeded."
fi

for f in site/profile/**/**pp; do
   [[ $f =~ plans/ ]] && continue
 
   if ! grep "^\s*create_resources" "$f"; then
      echo "SUCCESS: $f"
   else
      echo "FAILED: $f"
      failures_secruity+=("$f")
   fi
 
   if ! egrep "^.*file\s*\(.*\)" "$f"; then
      echo "SUCCESS: $f"
   else
      echo "FAILED: $f"
      failures_security+=("$f")
   fi
done
 
for f in site/role/**/**pp; do
   [[ $f =~ plans/ ]] && continue
 
   if ! grep "^\s*create_resources" "$f"; then
      echo "SUCCESS: $f"
   else
      echo "FAILED: $f"
      failures_security+=("$f")
   fi
 
   if ! egrep "^.*file\s*\(.*\)" "$f"; then
      echo "SUCCESS: $f"
   else
      echo "FAILED: $f"
      failures_security+=("$f")
   fi
done
 
if (( ${#failures_security[@]} > 0 )); then
   echo "Security validation on the Control Repo has failed in the following manifests:"
   echo -e "\t ${failures_security[@]}"
   exit 1
else
   echo "Syntax validation on the Control Repo has succeeded."
fi

for f in data/**/**yaml; do
  ruby -ryaml -e "YAML.parse(File.open('$f'))"

  if [[ $? -ne 0 ]]; then
    echo "$f is not valid YAML"
    failures_hiera+=("$f")
  else
    echo "$f is valid YAML"
  fi
done

if (( ${#failures_hiera[@]} > 0 )); then
   echo "Hiera validation on the Control Repo has failed in the following manifests:"
   echo -e "\t ${failures_hiera[@]}"
   exit 1
else
   echo "Hiera validation on the Control Repo has succeeded."
fi

bundle install
bundle exec r10k puppetfile check
bundle exec puppet-lint site/profile/manifests/
bundle exec puppet-lint site/profile/manifests/
bundle exec onceover run spec
