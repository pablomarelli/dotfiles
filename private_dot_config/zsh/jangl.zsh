# Jangl
export AWS_DEFAULT_REGION="us-east-1"
export CFLAGS="-Qunused-arguments"
export CPPFLAGS="-Qunused-arguments"
export DOCKER_DEFAULT_PLATFORM="linux/amd64"
export LC_ALL="en_US.utf-8"
export LANG="en_US.utf-8"
export PYTHONWARNINGS="ignore"

export PATH=$PATH:$HOME/.jangl/bin

alias site="./jangl-site"
alias dc="docker compose"
alias docker-compose="docker compose"
alias dcrun="docker compose run --rm --no-deps"

function dclogs {
    local dir=$(basename $(cd "$(dirname .)" && pwd))
    local project=${1/%\//}
    docker logs --tail=${2:-10} -f "${dir}-${project}-1"
}

alias dnsquery='dscacheutil -q host -a name'

ssh-add ~/.ssh/jangl_prod &>/dev/null
