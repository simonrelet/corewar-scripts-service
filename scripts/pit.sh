#! /bin/bash

VERSION="0.1"
SCRIPT_NAME=`basename $0`

ADDRESS="80.236.45.206"
URL="http://$ADDRESS:4201"
SCRIPTS_URL="http://$ADDRESS:4204"

help ()
{
  echo "Usage: $SCRIPT_NAME [options] ship"
  echo "       $SCRIPT_NAME update [options]"
  echo
  echo "The pit command utilities for building ships."
  echo
  echo "Options:"
  echo "   -h, --help     Displays this help."
  echo "   -b, --bin      Only outputs the ship if any."
  echo "   -v, --version  Displays the script version."
}

request ()
{
  curl -s -X POST --data-urlencode "ship@$1" "$URL/?pretty=true"
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

update_help ()
{
  echo "Usage: $SCRIPT_NAME update [options]"
  echo
  echo "Options:"
  echo "  -h, --help  Displays this help."
}

update ()
{
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    update_help
    return 0
  fi
  
  echo "Corewar Championship: $SCRIPT_NAME v$VERSION"
  echo
  
  local remote_version=`curl -s "$SCRIPTS_URL/pit/version"`
  if [ -z "$remote_version" ]; then
    echo "Cannot access scripts service"
    return 1
  fi
  
  if [[ "$VERSION" < "$remote_version" ]]; then
    echo "The version $remote_version is available"
    read -p "Do you want to update? (y/n [default]) " res
    if [[ "$res" == "y" || "$res" == "yes" ]]; then 
      echo "Updating..."
      
      local new_script=`curl -s "$SCRIPTS_URL/pit"`
      if [[ "$new_script" == Error* ]]; then
        echo "An error occured."
        return 1
      else
        local script_file="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$SCRIPT_NAME"
        echo "$new_script" > $script_file
        echo "Your ready to go!"
      fi
    fi
  else
    echo "This script is up to date!"
  fi
  
  return 0
}

if [ "$#" -eq 0 ]; then
  help
  exit 1
fi

case "$1" in
  -b|--bin )
    if [ "$#" -ne 2 ] || ! is_file "$2"; then
      help
      exit 1
    fi
    request_bin "$2"
    ;;
  update )
    shift
    update $@
   ;;
  -v|--version)
  echo "v$VERSION"
    ;;
  -h|--help )
    help
    ;;
  * )
    if ! is_file "$1"; then
      help
      exit 1
    fi
    request "$1"
    ;;
esac

exit $?
