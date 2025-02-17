# Example: docker build . -t dsvw && docker run -p 65412:65412 dsvw

FROM python:3.12.3-alpine3.18 AS build

RUN apk --no-cache add libxml2-dev libxslt-dev gcc python3 python3-dev py3-pip musl-dev linux-headers

RUN python3 -m ensurepip --upgrade && python3 -m pip install pex~=2.1.47
RUN mkdir /source
COPY requirements.txt /source/
RUN pex -r /source/requirements.txt -o /source/pex_wrapper

FROM python:3.12.3-alpine3.18 AS final

RUN apk upgrade --no-cache
WORKDIR /dsvw
RUN adduser -D dsvw && chown -R dsvw:dsvw /dsvw

COPY dsvw.py .
RUN sed -i 's/127.0.0.1/0.0.0.0/g' dsvw.py
# Ensure the pex_wrapper is copied to the correct location
COPY --from=build /source/pex_wrapper /dsvw/pex_wrapper

EXPOSE 65412
USER dsvw
CMD ["/dsvw/pex_wrapper", "dsvw.py"]
