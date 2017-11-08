[redmine]
scheme=http
host=localhost
port=8081
username=USERNAME
password=PASSWORD
finishedid=5
gachaid = 7
rankid=23
accountableid=34

[uris]
form=/login
login=/login
exportjson=/issues.json?sort=id:desc&c[]=description
usersjson=/users/

[output]
filepath=downloads/result.csv

[download]
limit=500
