#! /bin/bash

set -e
set -u

VERSION="0.4"
SCRIPT_NAME="$(basename "$0")"

ADDRESS="0.0.0.0"
PIT_PORT="0000"
STADIUM_PORT="0000"
SCRIPT_PORT="0000"

PIT_URL="http://$ADDRESS:$PIT_PORT"
STADIUM_URL="http://$ADDRESS:$STADIUM_PORT"
SCRIPTS_URL="http://$ADDRESS:$SCRIPT_PORT"

gen_keys_usage ()
{
  cat << EOF
Usage: $SCRIPT_NAME gen-keys [options]

Generates RSA private-public keys in PEM format.

Options:
  -h, --help           Displays this help.
  -k file, --key=file  Outputs the private key in file.
                       The default file is 'rsa.pem'.
  -p file, --pub=file  Outputs the public key in file.
                       The default file is 'rsa.pub.pem'.
EOF

  [ $# -eq 0 ] || exit "$1"
  exit
}

gen_keys ()
{
  local private_key='rsa.pem'
  local public_key='rsa.pub.pem'

  while [[ $# > 0 ]]; do
    case "$1" in
      -k )
        shift
        private_key="$1"
        ;;
      --key=* )
        private_key="${1#*=}"
        ;;
      -p )
        shift
        public_key="$1"
        ;;
      --pub=* )
        public_key="${1#*=}"
        ;;
      -h|--help )
        gen_keys_usage
        ;;
      * )
        gen_keys_usage 1
        ;;
    esac
    shift
  done

  [[ -z "$private_key" ]] || [[ -z "$public_key" ]] && gen_keys_usage 1

  printf "\n  1. Generating private key in %s\n\n" "$private_key"
  openssl genrsa -out "$private_key" -aes256 2048 || return 1

  printf "\n  2. Generating public key in %s\n\n" "$public_key"
  openssl rsa -in "$private_key" -out "$public_key" -outform PEM -pubout
}

leaderboard ()
{
  curl -s "$STADIUM_URL/leaderboard/?pretty=true"
}

pit_usage ()
{
  cat << EOF
Usage: $SCRIPT_NAME pit [options] ship

Builds a ship.

Options:
  -h, --help           Displays this help.
  -b file, --bin=file  Only outputs the ship if any.
EOF

  [ $# -eq 0 ] || exit "$1"
  exit
}

request ()
{
  curl -s -X POST --data-urlencode "ship@$1" "$PIT_URL/?pretty=true"
}

request_bin ()
{
  request "$1"  | awk 'ORS=""; /-- Begin Bin --/ { flag=1; next } /--  End Bin  --/ { flag=0 } flag { print }'
}

is_file ()
{
  [ -f "$1" ] && return 0
  printf "Error: '%s' is not a file\n" "$1"
  return 1
}

pit ()
{
  [ "$#" -ne 0 ] || pit_usage 1

  case "$1" in
    -b )
      [ "$#" -eq 2 ] && is_file "$2" && request_bin "$2" && return "$?"
      ;;
    --bin=* )
      is_file "${1#*=}" && request_bin "${1#*=}" && return "$?"
      ;;
    -h|--help )
      pit_usage
      ;;
    * )
      is_file "$1" && request "$1" && return "$?"
      ;;
  esac

  pit_usage 1
}

race_usage()
{
  cat << EOF
Usage: $SCRIPT_NAME race [options]
       $SCRIPT_NAME race <captain> <private-key> <ship>

Runs the ship and publish it (if it didn't crash) for the given
captain.

Parameters:
  <captain>      The name of the captain.
  <private-key>  The private key to use to sign the ship.
  <ship>         The ship to run and publish.

Options:
  -h, --help  Displays this help.
EOF

  [ $# -eq 0 ] || exit "$1"
  exit
}

race ()
{
  [ "$#" -eq 1 ] && [[ "$1" =~ ^(-h|--help)$ ]] && race_usage
  [ "$#" -eq 3 ] || race_usage 1
  is_file "$2" || race_usage 1
  is_file "$3" || race_usage 1

  printf "Signing ship...\n"
  signature="$(openssl dgst -sha256 -sign $2 $3 | openssl base64)"
  [ -n "$signature" ] || return 1
  printf "Publishing ship...\n"
  curl  -X POST \
        -d captain="$1" \
        --data-urlencode "ship@$3" \
        --data-urlencode signature="$signature" \
        "$STADIUM_URL/race/?pretty=true"
}

register_usage ()
{
  cat << EOF
Usage: $SCRIPT_NAME register [options]
       $SCRIPT_NAME register <captain> <public-key>

Registers a new captain. A captain is required to be able to publish a ship.

Parameters:
  <captain>     The name of the captain to register.
  <public-key>  The public key to use for this captain. It must be in
                PEM format.

Options:
  -h, --help  Displays this help.
EOF

  [ $# -eq 0 ] || exit "$1"
  exit
}

register ()
{
  [ "$#" -eq 1 ] && [[ "$1" =~ ^(-h|--help)$ ]] && register_usage
  [ "$#" -eq 2 ] || register_usage 1
  is_file "$2" || register_usage 1

  printf "Registering %s...\n" "$1"
  curl  -X POST \
        -d name="$1" \
        --data-urlencode "key@$2" \
        "$STADIUM_URL/captains/?pretty=true"
}

update_usage ()
{
  cat << EOF
Usage: $SCRIPT_NAME update [options]

Options:
  -h, --help  Displays this help.
EOF

  [ $# -eq 0 ] || exit "$1"
  exit
}

get_latest_version ()
{
  curl -s "$SCRIPTS_URL/version"
}

has_update ()
{
  local remote_version
  remote_version="$(get_latest_version)"
  [ "$?" -eq 0 ] || return 2
  [[ "$VERSION" < "$remote_version" ]] && return 0
  return 1
}

update ()
{
  [[ $# -eq 1 ]] && [[ "$1" =~ ^(-h|--help)$ ]] && update_usage

  printf "Corewar Championship Script v%s\n\n" "$VERSION"

  if has_update; then
    local latest=`get_latest_version`
    printf "The version %s is available" "$latest"
    read -p "Do you want to update? (y/n [default]) " res
    
    [[ "$res" == "y" ]] || [[ "$res" == "yes" ]] || return 0
    
    printf "Updating...\n"
    local new_script="$(curl -s "$SCRIPTS_URL")"
    [[ -z "$new_script" ]] && printf "Error: An error occured.\n" && return 1
    
    local script_file="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$SCRIPT_NAME"
    printf "%s" "$new_script" > $script_file
    printf "Your ready to go!\n"
  else
    [[ "$?" -eq 2 ]] && printf "Error: Cannot access scripts service\n" && return 1
    printf "This script is up to date!\n"
  fi
}

warm_up_usage ()
{
  cat << EOF
Usage: $SCRIPT_NAME warm-up [options] <ship>

Try out the ship but doesn't publish it.

Parameters:
  <ship>  The ship file

Options:
  -h, --help             Displays this help.
  -v l, --verbosity=l    The verbosity level to use, must be one of:
                         0: No logs
                         1: Execution messages, decoded instructions
                         2: Checked zones, registers content
                         3: Read and write addresses, boosts
                         3: Read and write values
  -f c, --first-cycle=c  Starts the logging at cycle c.
  -l c, --last-cycle=c   Stops the logging at cycle c.
EOF

  [ $# -eq 0 ] || exit "$1"
  exit
}

warm_up ()
{
  local verbosity=""
  local first_cycle=""
  local last_cycle=""
  local ship=""

  while [[ $# > 0 ]]; do
    case "$1" in
      -v )
        shift
        verbosity="$1"
        ;;
      --verbosity=* )
        verbosity="${1#*=}"
        ;;
      -f )
        shift
        first_cycle="$1"
        ;;
      --first-cycle=* )
        first_cycle="${1#*=}"
        ;;
      -l )
        shift
        last_cycle="$1"
        ;;
      --last-cycle=* )
        last_cycle="${1#*=}"
        ;;
      -h|--help )
        warm_up_usage
        ;;
      * )
        ship="$1"
        ;;
    esac
    shift
  done

  [ -n "$ship" ] || printf "Error: Where's the ship dude?\n" && warm_up_usage 1

  local params=""
  [ -z "$verbosity" ] || params+="&v=$verbosity"
  [ -z "$first_cycle" ] || params+="&f=$first_cycle"
  [ -z "$last_cycle" ] || params+="&l=$last_cycle"

  printf "Warming up...\n"
  curl -X POST --data-urlencode "ship@$ship" "$STADIUM_URL/warm-up/?pretty=true$params"
}

usage ()
{
  cat << EOF
Usage: $SCRIPT_NAME [options]
       $SCRIPT_NAME {gen-keys|leaderboard|pit|race|register|update|warm-up}

The corewar command utilities for building ships, managing captains, runing and
publishing ships.

Options:
  -h, --help     Displays this help.
  -v, --version  Displays the script version.
EOF

  [ $# -eq 0 ] || exit "$1"
  exit
}

[ "$#" -ne 0 ] || usage 1
[ "$1" != "update" ] && has_update && printf "A new version is available. Use '%s update'\n" "$SCRIPT_NAME"

case "$1" in
  -v|--version )
    printf "%s\n" "$VERSION"
    ;;
  -h|--help )
    usage
    ;;
  gen-keys )
    shift
    gen_keys $@
    ;;
  leaderboard )
    leaderboard
    ;;
  pit )
    shift
    pit $@
    ;;
  race )
    shift
    race $@
    ;;
  register )
    shift
    register $@
    ;;
  update )
    shift
    update $@
    ;;
  warm-up )
    shift
    warm_up $@
    ;;
  * )
    printf "Error: Unknown command '%s'\n" "$1"
    usage 1
    ;;
esac
