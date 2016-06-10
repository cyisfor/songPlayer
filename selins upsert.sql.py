tables = (
    ('recordings',
     '(hash = _hash)',
     (('hash', 'text'),)),
    ('songs',
     'title = _title',
     (('title', 'text'),)),
    ('artists',
     'name = _name',
     (('name', 'text'),)),
    ('albums',
     'title = _title',
     (('title', 'text'),)),
)


with open("selins upsert.sql") as inp:
    sql = inp.read()

for table in tables:
    name,clause,parameters = table
    paramnames = list(i[0] for i in parameters)
    unparameters = list(('_'+n,v) for n,v in parameters)
    unparamnames = list(t[0] for t in unparameters)
    psql = sql % {
        'table': name,
        'parameters': ','.join(unparamnames),
        'paramnames': ','.join(paramnames),
        'parametersWithType': ','.join(n+' '+v for n,v in unparameters),
        'clause': clause}
    print(psql)
