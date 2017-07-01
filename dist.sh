if [ $# -eq 0 ]; then
  echo "give me a parameter(file)!"
  exit 1
fi
grep -E "[0-9]\.[0-9]" $1 | sort -k 2 -V | sed -r 's/^(.+), (.+\..+)/\2/' | uniq -c | sed -r 's/(.+) (.+)/[\2] \1/'
