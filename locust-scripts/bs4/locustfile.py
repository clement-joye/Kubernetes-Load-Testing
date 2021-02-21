import os

from bs4 import BeautifulSoup
from locust import HttpUser, task, between

get_resources = os.getenv('LOCUST_DOWNLOAD_RESOURCES', "false")

pages = [ { "path": "/", "name": "Home Page" } ]

def isStaticFile(url):
    if ('/media/' in url) or ('/scripts/' in url) or ('/css/' in url):
        return True
    return False

class LocustUser(HttpUser):

    # Waiting time between request
    wait_time = between(1, 3)

    # Initialization
    def __init__(self, *args, **kwargs):
        super(LocustUser, self).__init__(*args, **kwargs)
    
    # Fetch resources (javascript, css, media...)
    def fetch_static_assets(self, response):

        resource_urls = set()
        soup = BeautifulSoup(response.text, "html.parser")
        
        for res in soup.find_all(src=True):

            url = res['src']
            
            if isStaticFile(url):
                resource_urls.add(url)
        
        for url in set(resource_urls):
            self.client.get(url, name="Website assets")

    # Wrapper function to include resources if needed
    def request_page(self, path, pageName):

        response = self.client.get( path, name = pageName )

        if get_resources == "true":
            self.fetch_static_assets(response)
    
    @task(1)
    def some_flow(self):

        self.request_page(pages[0]["path"], pages[0]["name"])
        self.client.cookies.clear()

