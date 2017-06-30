import re
import postgresql

pattern_version = r"^[0-9]+(\.[0-9]+){2}$"

db = postgresql.open("pq://postgres@localhost/instances")

def get_watching_uri():
  get_uris = db.prepare("select uri from list")
  with db.xact():
    for row in get_uris():
     print(row["uri"])

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

def update_version(uri, version):
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
#      if rows != 4:
#        raise Exception("Update Error")

def parse_str(obj):
  if obj is None:
    return ""
  else:
    return str(obj)

f = open('results.list')
line = f.readline()
line_num = 0
while line:
  if re.compile(", ").search(line):
    divided = re.compile(", ").split(line)
    uri=divided[0]
    version=divided[1]
  
    line_num += update_version(uri, version)
  line = f.readline()
f.close

f = open('table.html', 'w')
get_all_table = db.prepare("SELECT uri,status,version,updated,users,statuses,connections,registrations,ipv6,delay FROM list")

f.write("<table id=\"listTable\" class=\"tablesorter\"><thead><tr><th>Instance</th><th>Status</th><th>Version</th><th>Updated</th><th>Users</th><th>Toots</th><th>Connections</th><th>Registrations</th><th>IPv6</th><th>Delay(s)</th></tr></thead><tbody>")

with db.xact():
  for row in get_all_table():
    f.write("<tr><td>" + parse_str(row["uri"]) + "</td><td>" + parse_str(row["status"]) + "</td><td>" + parse_str(row["version"]) + "</td><td>" + parse_str(row["updated"]) + "</td><td>" + parse_str(row["users"]) + "</td><td>" + parse_str(row["statuses"]) + "</td><td>" + parse_str(row["connections"]) + "</td><td>" + parse_str(row["registrations"]) + "</td><td>" + parse_str(row["ipv6"]) + "</td><td>" + parse_str(row["delay"]) + "</td></tr>")
f.write("</tbody></table>")
f.close

#print(str(line_num) + " lines has been updated.")
