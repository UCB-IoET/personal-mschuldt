import requests
import json
"""
source:
  http://proj.storm.pm:8081/data/

archiver:
  http://shell.storm.pm:8079/api/query

"""

url = "http://shell.storm.pm:8079/api/query"

#r = """select uuid """#where Metadata/Location/Room = 'Invention Lab';"""
#r = """select distinct uuid where Metadata/Location/Room = 'Invention Lab';"""

#r = "select Metadata"
#r = "select Metadata/Name"
r = "select * where Metadata/Name like 'Lava Lamp'"


resp = requests.post(url, r)

print(resp.text)
