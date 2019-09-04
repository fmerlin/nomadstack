from elasticsearch import Elasticsearch
es = Elasticsearch()

res = es.search(index="requests", body=dict(query=dict(range=dict(msgSubmissionTime=dict(gte='now-5m', lt='now')))))
print(res)
