import postgresql
import os.path as path
import pdb

db = postgresql.open("pq://postgres@localhost/instances")

def split_version(uri):
  get_list = db.prepare("SELECT version FROM list WHERE uri = $1")
  with db.xact():
    row = get_list(uri)

get_list = db.prepare("SELECT uri, version FROM list")
replace_version = db.prepare('UPDATE list SET version = $2 WHERE uri = $1')
with db.xact():
  for row in get_list():
    if row is not None:
      uri = row['uri']
      if row['version'] is None:
        version = '0.0.0'
      else:
        version = row['version'].strip()
      if (version != '0.0.0'):
        replace_version(uri, version)
      else:
        replace_version(uri, None)
