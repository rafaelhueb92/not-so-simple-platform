from prometheus_client import Counter
REQUEST_COUNT = Counter("hello_requests_total", "Total requests")
