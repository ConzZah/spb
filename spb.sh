#!/usr/bin/env sh

## /// snowflake-proxy-builder // ConzZah // 2026-04-18 06:30 ///

printf "\n=== spb // ConzZah // 2026 ===\n"

init () {
static=""; proot=""; tmx=""; dbg=""; deb=""; alp=""; bs=""; o=""; v=""
## PROCESS ARGS ##
while [ $# -gt 0 ]; do
case $1 in
*s|*static) export static="1";; ## <-- link statically (requires musl)
*v|*verbose) export v="-v";; ## <-- be verbose during the build process
*dbg|*debug) export dbg="1";; ## <-- don't strip debug info from executable
*) printf "\nUSAGE: sh spb.sh [OPTION]\n\n[-dbg] [--debug]       do not strip debug info\n\n[-s] [--static]        link statically\n\n[-v] [--verbose]       be verbose\n\n[-h] [--help]          show help\n\n" && exit
esac
shift
done

snowflake_git="https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake.git"
tmx_proot_warn="--> PLEASE RE-LAUNCH IN ALPINE PROOT FOR STATIC BUILDS TO SUCCEED ON TERMUX."
env | grep -q termux && tmx="1" ## <-- check if running on termux
uname -v| grep -iq 'Debian' && deb="1" ## <-- check if running on debian
[ -n "$deb" ] || [ -n "$tmx" ] && pkg="apt install -yy"

## alpine-specific
[ -f "/etc/alpine-release" ] && \
doso="doas" && pkg="apk add" && alp="1"

## termux-specific ##
## if running termux, AND static was specified, check if we're running alpine via proot
## static builds will fail on termux otherwise, i tried, maybe i'm missing something, but that's okay.
[ -n "$tmx" ] && { [ -n "$alp" ] && { printf "\n--> TERMUX + ALPINE PROOT DETECTED\n\n"; proot="1" ;}
[ -z "$proot" ] && [ -n "$static" ] && printf '\n%s\n\n' "$tmx_proot_warn" && exit
}

cd "$HOME" || exit 1
## check for common dependencies
command -v "sudo" >/dev/null && doso="sudo"
deps="curl grep tar git"; for dep in $deps; do
! command -v "$dep" >/dev/null && eval "$doso $pkg $dep"
done

## if we're root, clear $doso
[ "$(whoami)" = "root" ] && doso=""

## check for system-specific build dependencies
## (debian & termux)
[ -n "$deb" ] || [ -n "$tmx" ] && [ -z "$alp" ] && \
{ [ "$(dpkg -l build-essential| tail -n1| cut -c -2)" = "un" ] && eval "$doso $pkg build-essential" ;}
## (alpine)
[ -n "$alp" ] && { ! apk query build-base --installed| grep -q build-base && eval "$doso $pkg build-base" ;}

sys="$(uname -s)"
case $sys in
Darwin) sys="darwin";;
Linux) sys="linux";;
*) printf '%s' "--> ERROR: $sys IS CURRENTLY NOT SUPPORTED" && exit 1
esac

arch="$(uname -m)"
[ -n "$tmx" ] && doso=""
case $arch in
armv7*|armv6*) arch="armv6l";;
aarch64) arch="arm64";;
x86_64) arch="amd64";;
i*86) arch="386";;
*) printf '%s' "--> ERROR: $arch IS CURRENTLY NOT SUPPORTED" && exit 1
esac
dl_go
}

dl_go () {
PFX="/usr/local"
export GOPROXY="direct"
export PATH="$PATH:$PFX/go/bin"
## if on termux and in proot, edit $PATH,
## so termux's binaries will not be used when building.
[ -n "$proot" ] && PATH="$(echo $PATH| sed 's#:/data/data/com.termux/files/usr/bin:/system/bin:/system/xbin##g')"

## download & install go if it's not installed already
! go version >/dev/null 2>&1 && { printf '\n%s\n\n' "--> DOWNLOADING GO.."

## if we are on termux and in proot,
## OR if we aren't on termux at all,
## download go the traditional way
[ -n "$proot" ] || [ -z "$tmx" ] && {
go_link="https://go.dev/dl"
go="$(curl -sL "$go_link"| grep 'Stable versions' -A420| grep -o -m1 "go.*${sys}-${arch}.*.gz"| cut -d '"' -f 1)"
go_link="$go_link/$go" && curl -#LO "$go_link" && \
$doso rm -rf "$PFX/go" && $doso tar -C "$PFX" "${v}" -xzf "$go" || exit 1
}

## if we are on termux, but aren't in proot, download go via apt
[ -n "$tmx" ] && [ -z "$proot" ] && $pkg golang ;}
go version >/dev/null && printf "\n--> GO INSTALL FOUND\n" && clone_snowflake || printf "\n--> GO INSTALL FAILED!\n\n" && exit 1
}

clone_snowflake () {
## clone / update snowflake-proxy
## should a local clone exist, run git pull
[ ! -d "$HOME/snowflake" ] && printf "\n--> CLONING SNOWFLAKE..\n\n" && \
git clone "$snowflake_git" && cd "$HOME/snowflake/proxy" || \
printf "\n--> UPDATING SNOWFLAKE..\n\n" && \
cd "$HOME/snowflake/proxy" && git pull
build_snowflake
}

build_snowflake () {
## setup default build
[ -z "$static" ] && {
o="proxy-$arch"
ldflags="-checklinkname=0"
printf "\n--> BUILDING SNOWFLAKE..\n"
}

## setup static build
[ -n "$static" ] && {
export CGO_ENABLED=1
o="proxy-static-$arch"
ldflags="-linkmode external -extldflags -static -checklinkname=0"
[ -z "$alp" ] && export CC=musl-gcc

## if running debian, set musl-gcc and install if needed
[ -n "$deb" ] && { ! command -v 'musl-gcc' >/dev/null && eval "$doso $pkg musl-dev musl-tools gcc" ;}
printf "\n--> BUILDING SNOWFLAKE & LINKING STATICALLY..\n"
}

## BUILD THAT SH!T ##
go build -a -ldflags="$ldflags" -o "$o" "${v}" && \
bs="0" && build_status || [ -z "$bs" ] && bs="1"; build_status
}

build_status () {
[ "$bs" = "1" ] && printf "\n--> FAILED TO BUILD SNOWFLAKE\n" && exit 1
[ "$bs" = "0" ] && { [ -z "$dbg" ] && command -v strip >/dev/null && strip "$o"
printf '\n%s\n' "--> SUCCESSFULLY BUILT SNOWFLAKE"
printf '\n%s\n\n%s\n\n' "--> LAUNCH SNOWFLAKE PROXY WITH:" "$HOME/snowflake/proxy/$o"; exit 0 ;}
}

init "$@"
