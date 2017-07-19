import re
import postgresql
import os.path as path
import pdb
from distutils.version import StrictVersion


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
    if (rows == 1) and (row["version"] is not None):
      return row["version"]
    else:
      return '0.0'

def insert_uri(uri):
  insert_list = db.prepare("INSERT INTO list(uri) VALUES($1)")
  insert_list.first(uri)

# if status is Up
def update_status_up(uri, status, version, delay, ipv6):
  if get_exsistence(uri) != 1:
    insert_uri(uri)

  # if version are updated
  if StrictVersion(get_version(uri)) != StrictVersion(version):
    update_list = db.prepare("UPDATE list SET status = $2, version = $3, delay = $4, ipv6 = $5, updated = now() WHERE uri = $1")
  else:
    update_list = db.prepare("UPDATE list SET status = $2, version = $3, delay = $4, ipv6 = $5 WHERE uri = $1")

  insert_updates = db.prepare("INSERT INTO updates VALUES($1, now(), $2)") 
  if get_version(uri) == version or not re.compile(pattern_version).search(version) :
    return 0
  else: 
    with db.xact():
      rows = 0
      for row in update_list(uri, status, version, delay, ipv6):
        rows += 1
      for row in insert_updates(uri, version):
        rows += 1
      return 1
    # postgresql exception
    return 0

# if status is Down
def update_status_down(uri, status):
  if get_exsistence(uri) != 1:
    insert_uri(uri)
  update_list = db.prepare("UPDATE list SET status = $2 WHERE uri = $1")
  return 1

def update_scraped(uri, users, statuses, connections, registration):
  update_list = db.prepare("UPDATE list SET users = $2, statuses = $3, connections = $4, registration = $5 WHERE uri = $1")
  with db.xact():
    rows = 0
    for row in update_list(uri, users, statuses, connections, registration):
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

# update instance info from result.txt
f = open('result.txt')
line = f.readline()
line_num = 0
while line:
  divided = divide_line(line, ", ")
  if divided is not None:
    uri = divided[0]
    status = divided[1]
    if status == 'Up':
      version = divided[2]
      delay = float(divided[3])
      ipv6 = divided[4].strip()
      line_num += update_status_up(uri, True, version, delay, ipv6)
    else:
      line_num += update_status_down(uri, False)
  line = f.readline()
f.close

# update scraped info
if path.exists('scrape.txt'):
  f=open('scrape.txt')
  line = f.readline()
  while line:
    divided = divide_line(line, ",")
    if divided is not None:
      uri = divided[0]
      try:
        users = int(re.sub(r'^$', '-1', divided[1].replace(' ', '').replace('.','')))
        statuses = int(re.sub(r'^$', '-1', divided[2].replace(' ', '').replace('.','')))
        connections = int(re.sub(r'^$', '-1', divided[3].replace(' ', '').replace('.','')))
        registration = bool(divided[4].replace('\n', ''))
      except:
        pass
      update_scraped(uri, users, statuses, connections, registration)
    line = f.readline()
  f.close

# update uptime info

# write down table
f = open('table.html', 'w')
get_all_table = db.prepare("SELECT uri,status,version,updated,users,statuses,connections,registration,ipv6,delay FROM list order by uri")
f.write("<table id=\"listTable\" class=\"tablesorter\"><thead><tr><th>Instance</th><th>Status</th><th>Version</th><th>Updated</th><th>Users</th><th>Toots</th><th>Connections</th><th>Registration</th><th>IPv6</th><th>Delay[ms]</th></tr></thead><tbody>")

with db.xact():
  for row in get_all_table():
    f.write("<tr><td>" + parse_str(row["uri"]) + "</td><td>" + parse_str(row["status"]) + "</td><td>" + parse_str(row["version"]) + "</td><td>" + parse_str(row["updated"]) + "</td><td>" + parse_str(row["users"]) + "</td><td>" + parse_str(row["statuses"]) + "</td><td>" + parse_str(row["connections"]) + "</td><td>" + parse_str(row["registration"]) + "</td><td>" + parse_str(row["ipv6"]) + "</td><td>" + parse_str(row["delay"]) + "</td></tr>")
f.write("</tbody></table>")
f.close

#print(str(line_num) + " lines has been updated.")
