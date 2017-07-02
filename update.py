import re
import postgresql
import os.path as path

pattern_version = r"^[0-9]+(\.[0-9]+){2}$"

db = postgresql.open("pq://postgres@localhost/instances")

def get_watching_uri():
  get_list = db.prepare("SELECT uri FROM list")
  with db.xact():
    for row in get_list():
     print(row["uri"])

def get_exsistence(uri):
  get_list = db.prepare("SELECT count(*) FROM list WHERE uri = $1")
  with db.xact():
    for row in get_list( uri ):
      return row[0]


def get_version(uri):
  get_list = db.prepare("SELECT version FROM list WHERE uri = $1")
  with db.xact():
    rows = 0
    for row in get_list(uri):
      rows += 1
    if rows == 1:
      return row["version"]
    else:
      return None

def insert_uri(uri):
  insert_list = db.prepare("INSERT INTO list(uri) VALUES($1)")
  insert_list.first(uri)

def update_status(uri, status):
  None

def update_version(uri, version):

  if get_exsistence(uri) != 1:
    insert_uri(uri)
  # update up status

  update_list = db.prepare("UPDATE list SET version = $2, updated = now() where uri = $1")
  insert_updates = db.prepare("INSERT INTO updates VALUES($1, now(), $2)") 
  if get_version(uri) == version or not re.compile(pattern_version).search(version) :
    return 0
  else: 
    with db.xact():
      rows = 0
      for row in update_list(uri, version):
        rows += 1
      for row in insert_updates(uri, version):
        rows += 1
      return 1
    # postgresql exception
    return 0

def update_delay(uri, delay):
  update_list = db.prepare("UPDATE list SET delay = $2 where uri = $1")
  with db.xact():
    rows = 0
    for row in update_list(uri, delay):
      rows += 1
    return 1
  # postgresql exception
  return 0

def parse_str(obj):
  if obj is None:
    return ""
  else:
    return str(obj)

def divide_line(line, pattern):
  if re.compile(pattern).search(line):
    return re.compile(pattern).split(line)
  else:
    return None

# update version info
f = open('version.txt')
line = f.readline()
line_num = 0
while line:
  divided = divide_line(line, ", ")
  if divided is not None:
    uri=divided[0]
    version=divided[1]
    line_num += update_version(uri, version)
  line = f.readline()
f.close

# update delay info
if path.exists('time.txt') :
  f = open('time.txt')
  line = f.readline()
  line_num = 0
  while line:
    divided = divide_line(line, ", ")
    if divided is not None:
      uri = divided[0]
      delay = float(divided[1])
      line_num += update_delay(uri, delay)
    line = f.readline()
  f.close

# update uptime info

# write down table
f = open('table.html', 'w')
get_all_table = db.prepare("SELECT uri,status,version,updated,users,statuses,connections,registrations,ipv6,delay FROM list order by uri")
f.write("<table id=\"listTable\" class=\"tablesorter\"><thead><tr><th>Instance</th><th>Status</th><th>Version</th><th>Updated</th><th>Users</th><th>Toots</th><th>Connections</th><th>Registrations</th><th>IPv6</th><th>Delay[ms]</th></tr></thead><tbody>")

with db.xact():
  for row in get_all_table():
    f.write("<tr><td>" + parse_str(row["uri"]) + "</td><td>" + parse_str(row["status"]) + "</td><td>" + parse_str(row["version"]) + "</td><td>" + parse_str(row["updated"]) + "</td><td>" + parse_str(row["users"]) + "</td><td>" + parse_str(row["statuses"]) + "</td><td>" + parse_str(row["connections"]) + "</td><td>" + parse_str(row["registrations"]) + "</td><td>" + parse_str(row["ipv6"]) + "</td><td>" + parse_str(row["delay"]) + "</td></tr>")
f.write("</tbody></table>")
f.close

#print(str(line_num) + " lines has been updated.")
