import re
import time
import postgresql
import os.path as path
import pdb
import fasteners
import time
import psycopg2
import psycopg2.extras

from pprint import pprint

from distutils.version import StrictVersion
from mastodon import Mastodon

pattern_version = r"^[0-9]+(\.[0-9]+){2}$"
lockfile = 'update.lock'
resultfile = 'result.txt'
scrapefile = 'scrape.txt'

db = postgresql.open("pq://postgres@localhost/instances")

mastodon = Mastodon(
    client_id = 'pytooter_clientcred.secret',
    access_token = 'pytooter_usercred.secret',
    api_base_url = 'https://don.tacostea.net'
    )

def get_watching_uri():
  get_list = db.prepare("SELECT uri FROM target WHERE crawl = True")
  with db.xact():
    for row in get_list():
     print(row["uri"])

def get_version(uri):
  get_list = db.prepare("SELECT version FROM updates WHERE uri = $1 AND version <> '?(down)' ORDER BY updated DESC LIMIT 1")
  with db.xact():
    rows = 0
    for row in get_list(uri):
      rows += 1
    if (rows == 1) and (row["version"] is not None):
      return row["version"]
    else:
      return '0.0.0'

def get_status(uri):
  get_list = db.prepare("SELECT status FROM info WHERE uri = $1")
  result = get_list(uri)
  if len(result) == 1: return result[0][0]
  else: return 'down'

def get_mean_delay(uri, delay):
  get_list = db.prepare('SELECT delay FROM list WHERE uri = $1')
  with db.xact():
    for result in get_list(uri):
      if result['delay'] is not None:
        return round((delay + float(result['delay'])) / 2, 3)
      else:
        return None

# if status is Up
def update_status_up(uri, status, version, delay, ipv6):
  delay = get_mean_delay(uri, delay)
  old = get_version(uri).strip()
  if old == '0.0.0' : old = '!FIRST FETCH!'
  
  # if version are updated
  if old != version and version is not None:
    for i in range(10):
      try:
        mastodon.status_post('[ Version Updated! ]\n' + uri + ' : '+ old + ' -> ' + version + '\n#Mastodon_Upgrade_Battle #tacobot')
        print('[ Version Updated! ]\n' + uri + ' : '+ old + ' -> ' + version + '\n#Mastodon_Upgrade_Battle #tacobot')
        update_list = db.prepare("UPDATE list SET status = $2, version = $3, delay = $4, ipv6 = $5, updated = now() WHERE uri = $1")
        update_info = db.prepare("UPDATE info SET status = $2, delay = $3, ipv6 = $4, updated = now() WHERE uri = $1")
        insert_updates = db.prepare("INSERT INTO updates VALUES($1, now(), $2)") 

        update_list(uri, status, version, delay, ipv6)
        update_info(uri, "up", delay, ipv6)
        insert_updates(uri, version)

      except Exception as e:
        print("exception " + str(e))
        time.sleep(10)

      else:
        break

# if status is Down
def update_status_down(uri, status):
  insert_updates = db.prepare("INSERT INTO updates VALUES ($1, now(), '?(down)')")
  insert_updates(uri)
  update_list = db.prepare("UPDATE list SET status = $2 WHERE uri = $1")
  update_list(uri, status)
  update_info = db.prepare("UPDATE info SET status = 'down', updated = now() WHERE uri = $1")
  update_info(uri)

def update_scraped(uri, users, statuses, connections, registration):
  update_list = db.prepare("UPDATE list SET users = $2, statuses = $3, connections = $4, registration = $5 WHERE uri = $1")
  update_info = db.prepare("UPDATE info SET users = $2, statuses = $3, connections = $4, registration = $5, updated = now() WHERE uri = $1")
  with db.xact():
    update_info(uri, users, statuses, connections, registration)
    rows = 0
    for row in update_list(uri, users, statuses, connections, registration):
      rows += 1
    return 1
  # postgresql exception

  update_info = db.prepare("UPDATE info SET users = $2, statuses = $3, connections = $4, registration = $5 WHERE uri = $1")
  update_info(uri, users, statuses, connections, registration)
  
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

with fasteners.InterProcessLock(lockfile):
  # update instance info from result.txt
  if path.exists(resultfile):
    f = open(resultfile)
    try:
      line = f.readline()
    except:
      line = f.readline()

    while line:
      divided = divide_line(line, ", ")
      if divided is not None and len(divided) > 4:
        uri = parse_str(divided[0]).replace('\x00','')
        if not re.match(r".+\..+", uri): continue
        status = divided[1]
        recorded_status = get_status(uri)

        if status == 'Up':
          version = divided[2].strip() if divided[2].strip() != '0.0.0' else None
          delay = float(divided[3])
          ipv6 = divided[4].strip()
          if not re.match(r".*[0-9x]$", ipv6): continue
          query = db.prepare("UPDATE activity SET (updated, uptime) = (now(), uptime + age(now(), updated)) WHERE uri = $1")
          update_status_up(uri, True, version, delay, ipv6)
        else:
          update_status_down(uri, False)
          query = db.prepare("UPDATE activity SET (updated, downtime) = (now(), downtime + age(now(), updated))) WHERE uri = $1")
        with db.xact():
          query(uri)

      try:
        line = f.readline()
      # read more next line if exception has occured
      except:
        line = f.readline()
      time.sleep(0.01)
    f.close
  
  # update scraped info
  if path.exists(scrapefile):
    f=open(scrapefile)
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
  
  with db.xact():
    for row in get_all_table():
      registration = 'Open' if row['registration'] == True else 'Close'
      status = 'Up' if row['status'] == True else 'Down'
      version = '' if row["version"] == '0.0.0' else parse_str(row["version"])
      users = '' if row["users"] == -1 else parse_str(row["users"])
      statuses = '' if row["statuses"] == -1 else parse_str(row["statuses"])
      connections = '' if row["connections"] == -1 else parse_str(row["connections"])
      delay = '' if row["delay"] is None else parse_str(round(row["delay"], 1))
  
      f.write("<tr><td>" 
      + parse_str(row["uri"]) + "</td><td>" 
      + status + "</td><td>" 
      + version + "</td><td>" 
      + parse_str(row["updated"]).split('.')[0] + "</td><td>" 
      + users + "</td><td>" 
      + statuses + "</td><td>" 
      + connections + "</td><td>" 
      + registration + "</td><td>" 
      + parse_str(row["ipv6"]) + "</td><td>" 
      + delay + "</td><td>"
      + "</td><td>"
      + "</td></tr>\n"
      )
  f.close
  pass
