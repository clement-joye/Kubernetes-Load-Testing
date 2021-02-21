FROM locustio/locust

RUN pip3 install beautifulsoup4

USER root
ENTRYPOINT ["locust"]

ENV PYTHONUNBUFFERED=1
