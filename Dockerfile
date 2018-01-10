FROM debian:9 AS proot
RUN apt-get update && apt-get install -q -y build-essential git libseccomp-dev libtalloc-dev
ADD proot/PRoot /PRoot
RUN cd PRoot/src && make && mv proot / && make clean

FROM golang:1.9-alpine AS runc
RUN apk add --no-cache git g++ linux-headers
RUN git clone https://github.com/opencontainers/runc.git /go/src/github.com/opencontainers/runc \
  && cd /go/src/github.com/opencontainers/runc \
  && git checkout -q e6516b3d5dc780cb57a976013c242a9a93052543 \
  && go build -o /runc .

FROM golang:1.9-alpine AS runrootless
COPY . /go/src/github.com/AkihiroSuda/runrootless/
RUN go build -o /runrootless github.com/AkihiroSuda/runrootless

FROM alpine:3.7
RUN adduser -u 1000 -D user && mkdir -p -m 0700 /run/user/1000 && chown 1000:1000 /run/user/1000
USER user
WORKDIR /home/user
ENV PATH=/home/user/bin:$PATH
ENV XDG_RUNTIME_DIR=/run/user/1000
COPY --from=proot --chown=user /proot /home/user/.runrootless/runrootless-proot
COPY --from=runc --chown=user /runc /home/user/bin/runc
COPY --from=runrootless --chown=user /runrootless /home/user/bin/runrootless
COPY --chown=user ./examples /home/user/examples
# note: --privileged is required to run this container: https://github.com/opencontainers/runc/issues/1456
