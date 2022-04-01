FROM debian:buster-slim

RUN apt update
RUN apt install zip unzip

RUN rm -rf /var/lib/apt/lists/*