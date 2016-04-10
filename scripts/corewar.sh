#! /bin/bash

VERSION="0.2"
SCRIPT_NAME=`basename $0`

ADDRESS="80.236.45.206"
PIT_URL="http://$ADDRESS:4201"
STADIUM_URL="http://$ADDRESS:4202"
SCRIPTS_URL="http://$ADDRESS:4204"

gen_keys_help ()
{
  echo "Usage: $SCRIPT_NAME gen-keys [options]"
  echo
  echo "Generates RSA private-public keys in PEM format."
  echo
  echo "Options:"
  echo "  -h, --help           Displays this help."
  echo "  -k file, --key=file  Outputs the private key in file."
  echo "                       The default file is 'rsa.pem'."
  echo "  -p file, --pub=file  Outputs the public key in file."
  echo "                       The default file is 'rsa.pub.pem'."
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
        public_key="${i#*=}"
        ;;
      -h|--help )
        gen_keys_help
        return 0
        ;;
      * )
        gen_keys_help
        return 1
        ;;
    esac
    shift
  done

  if [[ -z "$private_key" || -z "$public_key" ]]; then
    gen_keys_help
    return 1
  fi

  echo -e "\n  1. Generating private key in $private_key\n"
  openssl genrsa -out "$private_key" -aes256 2048
  if [ "$?" -eq 0 ]; then
    echo -e "\n  2. Generating public key in $public_key\n"
    openssl rsa -in "$private_key" -out "$public_key" -outform PEM -pubout
    return $?
  else
    return 1
  fi
}

leaderboard ()
{
  curl -s "$STADIUM_URL/leaderboard/?pretty=true"
}

pit_help ()
{
  echo "Usage: $SCRIPT_NAME pit [options] ship"
  echo
  echo "Builds a ship."
  echo
  echo "Options:"
  echo "   -h, --help     Displays this help."
  echo "   -b, --bin      Only outputs the ship if any."
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
  if [ ! -f "$1" ]; then
    echo "$1" is not a file
    return 1
  fi
  return 0
}

pit ()
{
  if [ "$#" -eq 0 ]; then
    pit_help
    return 1
  fi
  
  case "$1" in
    -b|--bin )
      if [ "$#" -ne 2 ] || ! is_file "$2"; then
        pit_help
        return 1
      fi
      request_bin "$2"
      ;;
    -h|--help )
      pit_help
      ;;
    * )
      if ! is_file "$1"; then
        pit_help
        exit 1
      fi
      request "$1"
      ;;
  esac
  
  return $?
}

race_help()
{
  echo "Usage: $SCRIPT_NAME race [options]"
  echo "       $SCRIPT_NAME race <captain> <private-key> <ship>"
  echo
  echo "Runs the ship and publish it (if it didn't crash) for the given"
  echo "captain."
  echo
  echo "Parameters:"
  echo "  <captain>      The name of the captain."
  echo "  <private-key>  The private key to use to sign the ship."
  echo "  <ship>         The ship to run and publish."
  echo
  echo "Options:"
  echo "  -h, --help  Displays this help."
}

race ()
{
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    race_help
    return 0
  fi

  if [ "$#" -ne 3 ]; then
    race_help
    return 1
  fi
  if [ ! -f "$2" ]; then
    echo "The private key file doesn't exists."
    race_help
    return 1
  fi
  if [ ! -f "$3" ]; then
    echo "The ship file doesn't exists."
    race_help
    return 1
  fi

  echo "Signing ship..."
  signature=`openssl dgst -sha256 -sign $2 $3 | openssl base64`
  if [ -z "$signature" ]; then
    return 1
  fi
  echo "Publishing ship..."
  curl -X POST -d captain="$1" --data-urlencode "ship@$3" --data-urlencode signature="$signature" "$STADIUM_URL/race/?pretty=true"
  return $?
}

register_help ()
{
  echo "Usage: $SCRIPT_NAME register [options]"
  echo "       $SCRIPT_NAME register <captain> <public-key>"
  echo
  echo "Registers a new captain. A captain is required to be able to publish a ship."
  echo
  echo "Parameters:"
  echo "  <captain>     The name of the captain to register."
  echo "  <public-key>  The public key to use for this captain. It must be in"
  echo "                PEM format."
  echo
  echo "Options:"
  echo "  -h, --help  Displays this help."
}

register ()
{
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    register_help
    return 0
  fi

  if [ "$#" -ne 2 ]; then
    register_help
    return 1
  fi
  if [ ! -f "$2" ]; then
    echo "The public key file doesn't exists."
    register_help
    return 1
  fi

  echo "Registering $1..."
  curl -X POST -d name="$1" --data-urlencode "key@$2" "$STADIUM_URL/captains/?pretty=true"
  return $?
}

update_help ()
{
  echo "Usage: $SCRIPT_NAME update [options]"
  echo
  echo "Options:"
  echo "  -h, --help  Displays this help."
}

get_latest_version ()
{
  curl -s "$SCRIPTS_URL/version"
  return $?
}

has_update ()
{
  remote_version=`get_latest_version`
  if [ "$?" -ne 0 ]; then
    return 2
  fi
  if [[ "$VERSION" < "$remote_version" ]]; then
    return 0
  fi
  return 1
}

update ()
{
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    update_help
    return 0
  fi

  echo "Corewar Championship Script v$VERSION"
  echo

  has_update
  case "$?" in
    2 )
      echo "Cannot access scripts service"
      return 1
      ;;
    1 )
      echo "This script is up to date!"
      ;;
    0 )
      local latest=`get_latest_version`
      echo "The version $latest is available"
      read -p "Do you want to update? (y/n [default]) " res
      if [[ "$res" == "y" || "$res" == "yes" ]]; then 
        echo "Updating..."
        
        local new_script=`curl -s "$SCRIPTS_URL"`
        if [[ "$new_script" == Error* ]]; then
          echo "An error occured."
          return 1
        else
          local script_file="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$SCRIPT_NAME"
          echo "$new_script" > $script_file
          echo "Your ready to go!"
        fi
      fi
    ;;
  esac

  return 0
}

warm_up_help ()
{
  echo "Usage: $SCRIPT_NAME warm-up [options] <ship>"
  echo
  echo "Try out the ship but doesn't publish it."
  echo
  echo "Parameters:"
  echo "  <ship>  The ship file"
  echo
  echo "Options:"
  echo "  -h, --help             Displays this help."
  echo "  -v l, --verbosity=l    The verbosity level to use, must be one of:"
  echo "                         0: No logs"
  echo "                         1: Execution messages, decoded instructions"
  echo "                         2: Checked zones, registers content"
  echo "                         3: Read and write addresses, boosts"
  echo "                         3: Read and write values"
  echo "  -f c, --first-cycle=c  Starts the logging at cycle c."
  echo "  -l c, --last-cycle=c   Stops the logging at cycle c."
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
        warm_up_help
        return 0
        ;;
      * )
        ship="$1"
        ;;
    esac
    shift
  done

  if [ -z "$ship" ]; then
    echo "Where's the ship dude?"
    warm_up_help
    return 1
  fi

  local params=""
  if [ ! -z "$verbosity" ]; then
    params+="&v=$verbosity"
  fi
  if [ ! -z "$first_cycle" ]; then
    params+="&f=$first_cycle"
  fi
  if [ ! -z "$last_cycle" ]; then
    params+="&l=$last_cycle"
  fi

  echo "Warming up..."
  curl -X POST --data-urlencode "ship@$ship" "$STADIUM_URL/warm-up/?pretty=true$params"
  return $?
}

help ()
{
  echo "Usage: $SCRIPT_NAME [options]"
  echo "       $SCRIPT_NAME <command>"
  echo
  echo "The corewar command utilities for building ships, managing captains, runing and"
  echo "publishing ships."
  echo
  echo "Commands:"
  echo "  gen-keys, leaderboard, pit, race, register, update, warm-up"
  echo
  echo "Options:"
  echo "  -h, --help     Displays this help."
  echo "  -v, --version  Displays the script version."
}

if [ "$#" -eq 0 ]; then
  help
  exit 1
fi

if [ "$1" != "update" ] && has_update; then
  echo "A new version is available. Use '$SCRIPT_NAME update'"
fi

case "$1" in
  -v|--version )
    echo $VERSION
    ;;
  -h|--help )
    help
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
    echo "Unknown command: $1"
    help
    exit 1
    ;;
esac

exit $?