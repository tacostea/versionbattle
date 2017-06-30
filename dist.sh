sort -k 2 -V results.list | sed -r 's/^(.+) (([0-9?]\.){2}[0-9?])/\2/' | uniq -c | sed -r 's/(.+) (.+)/[\2] \1/'
