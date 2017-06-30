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

f.write("<table><tr><th>Instance</th><th>Status</th>Version<th>Updated</th><th>Users</th><th>Toots</th><th>Connections</th><th>Registrations</th><th>IPv6</th><th>Delay</th></tr>")

with db.xact():
  for row in get_all_table():
    f.write("<tr>" + row["uri"] + row["status"] + row["version"] + row["updated"] + row["users"] + row["statuses"] + row["connections"] + row["registrations"] + row["ipv6"] + row["delay"] + "</tr>")
f.write("</table>")
f.close

#print(str(line_num) + " lines has been updated.")
