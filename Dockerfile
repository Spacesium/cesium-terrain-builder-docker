# Fetch stage #################################################################
FROM debian:buster AS fetchstage
ARG FETCH_PACKAGES='git ca-certificates'

WORKDIR /spctemp

# Setup fetch packages
RUN set -x && apt-get update && \
  apt-get install -y --no-install-recommends $FETCH_PACKAGES

# Fetch
# RUN set -x && \
#   git clone -b master-quantized-mesh --depth 1 \
#     https://github.com/ahuarte47/cesium-terrain-builder.git && \
#   cd cesium-terrain-builder

COPY ./cesium-terrain-builder cesium-terrain-builder

RUN cd cesium-terrain-builder

# Build stage #################################################################
FROM debian:buster AS buildstage
ARG BUILD_PACKAGES='cmake build-essential libgdal-dev'
COPY --from=fetchstage /spctemp/cesium-terrain-builder /spctemp/cesium-terrain-builder

WORKDIR /spctemp/cesium-terrain-builder

# Setup build packages
RUN set -x && \
  apt-get update && \
  apt-get install -y --no-install-recommends $BUILD_PACKAGES

# Build & install cesium terrain builder
RUN set -x && \
  ls -lahF && \
  mkdir build && cd build && cmake .. && make install .

# Cleanup
# RUN  set -x && \
#   apt-get purge -y --auto-remove $BUILD_PACKAGES && \
#   rm -rf /var/lib/apt/lists/* && \
#   rm -rf /tmp/* && \
#   rm -rf /spctemp

# Runtime stage ###############################################################
FROM debian:buster-slim

ARG RUNTIME_PACKAGES='gdal-bin'

# Copy headers
COPY --from=buildstage /usr/local/include/ctb /usr/local/include/ctb

# Copy Shared Object (.so) file 
COPY --from=buildstage /usr/local/lib/libctb.so /usr/local/lib/libctb.so

# Copy executables to /usr/local/bin
COPY --from=buildstage /usr/local/bin/ctb-* /usr/local/bin/

COPY --from=buildstage /usr/local/include/ctb /spc-build/usr/local/include/ctb
COPY --from=buildstage /usr/local/lib/libctb.so /spc-build/usr/local/lib/libctb.so
COPY --from=buildstage /usr/local/bin/spc-* /spc-build/usr/local/bin/

COPY --from=buildstage /spctemp /spctemp

WORKDIR /data

# Setup runtime packages and env
RUN set -x && apt-get update && \
  apt-get install -y --no-install-recommends $RUNTIME_PACKAGES && \
  ldconfig && \
  echo 'shopt -s globstar' >> ~/.bashrc && \
  echo 'alias ..="cd .."' >> ~/.bashrc && \
  echo 'alias l="ls -CF --group-directories-first --color=auto"' >> ~/.bashrc && \
  echo 'alias ll="ls -lFh --group-directories-first --color=auto"' >> ~/.bashrc && \
  echo 'alias lla="ls -laFh --group-directories-first  --color=auto"' >> ~/.bashrc

CMD ["bash"]

# Labels ######################################################################
# LABEL maintainer="Bruno Willenborg"
# LABEL maintainer.email="b.willenborg(at)tum.de"
# LABEL maintainer.organization="Chair of Geoinformatics, Technical University of Munich (TUM)"
# LABEL source.repo="https://github.com/tum-gis/https://github.com/tum-gis/cesium-terrain-builder-docker"
# LABEL docker.image="tumgis/ctb-quantized-mesh"
