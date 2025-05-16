# syntax=docker/dockerfile:1
#
ARG IMAGEBASE=frommakefile
#
FROM ${IMAGEBASE} AS builder
#
ARG NPROC=6
ARG TARGETPLATFORM
# ARG REPO=https://github.com/jacksonliam/mjpg-streamer
ARG REPO=https://github.com/ArduCAM/mjpg-streamer
ARG VERSION=master
#
COPY patches/ /tmp/
#
RUN set -xe \
    && apk add --no-cache --purge -uU \
        # build-base \
        # cmake \
        git \
        libgphoto2-dev \
        libjpeg-turbo-dev \
        linux-headers \
        sdl12-compat-dev \
#
        libcamera-dev \
        # libcamera-gstreamer \
        libcamera-raspberrypi \
        libcamera-tools \
        libcamera-v4l2 \
#
        libprotobuf \
        protobuf-c-dev \
        zeromq-dev \
#
        # ffmpeg
        # opencv-dev \
        # python3-dev \
        # py3-opencv \
        # py3-numpy \
#
    # skip since we compiling
        # raspberrypi-dev \
        # raspberrypi-userland-dev \
        # raspberrypi-userland-libs \
        sudo \
#
# grab a working compiler that doesn't scream error on warnings we don't care about
    && { \
        echo "http://dl-cdn.alpinelinux.org/alpine/v3.20/main"; \
        echo "http://dl-cdn.alpinelinux.org/alpine/v3.20/community"; \
    } > /tmp/repo3.20 \
    && apk add --no-cache \
        --repositories-file "/tmp/repo3.20" \
        build-base \
        cmake \
#
# compile userland as per https://github.com/jacksonliam/mjpg-streamer/issues/397
    && git clone https://github.com/raspberrypi/userland /tmp/userland \
    && cd /tmp/userland \
    && git revert --no-edit --no-commit f97b1af1b3e653f9da2c1a3643479bfd469e3b74 \
    && git revert --no-edit --no-commit e31da99739927e87707b2e1bc978e75653706b9c \
    && sed -i \
        '/^target_link_libraries(mmal mmal_core mmal_util mmal_vc_client vcos mmal_components)*/i SET(CMAKE_SHARED_LINKER_FLAGS "-Wl,--no-as-needed")' \
        ./interface/mmal/CMakeLists.txt \
    && case ${TARGETPLATFORM} in \
        'linux/arm64'|'linux/arm64/v8'|'linux/arm/v8') ./buildme --aarch64;; \
        'linux/arm'|'linux/arm32'|'linux/arm/v7'|'linux/armhf') ./buildme;; \
        'linux/arm/v6'|'linux/armel') ./buildme;; \
    esac \
#
# compile mjpg_streamer
    # && mkdir /tmp/build \
    # && cd /tmp/build \
    # && curl -jSLNO ${REPO}/archive/${VERSION}.tar.gz \
    # && tar -xf ${VERSION}.tar.gz \
    # && cd /tmp/build/mjpg-streamer-master/mjpg-streamer-experimental \
#
    && git clone ${REPO} /tmp/build -b "${VERSION}" --depth 1 \
    && cd /tmp/build \
    # patch from https://github.com/jacksonliam/mjpg-streamer/pull/305
    && git apply /tmp/ENABLE_HTTP_MANAGEMENT.patch \
    # # patch to modify dep-checker to look for OpenCV 4.x.x instead of 3.x.x
    # && git apply /tmp/OPENCV_BUMP.patch \
    && cd /tmp/build/mjpg-streamer-experimental \
#
    && mkdir _build \
    && cd _build \
    && cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_HTTP_MANAGEMENT=ON \
        -DWXP_COMPAT=ON \
        .. \
    && make -j ${NPROC} \
    && make install \
    && rm -rf /var/cache/apk/* /tmp/*
#
FROM ${IMAGEBASE} AS main
#
RUN set -xe \
    && apk add --no-cache --purge -uU \
        libgphoto2 \
        libjpeg-turbo \
        sdl12-compat \
#
        libcamera \
        # libcamera-gstreamer \
        libcamera-raspberrypi \
        libcamera-tools \
        libcamera-v4l2 \
        v4l-utils \
#
        libzmq \
        protobuf-c \
#
        # ffmpeg \
        # opencv \
        # python3 \
        # py3-opencv \
        # py3-numpy \
#
    # skip since we compiled
        # raspberrypi \
        # raspberrypi-userland \
        # raspberrypi-userland-libs \
        # raspberrypi-userland-udev \
    && rm -rf /var/cache/apk/* /tmp/*
#
COPY --from=builder /opt/vc /opt/vc
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/share /usr/local/share
COPY root/ /
#
ENV \
    MJPGST_PORT=8080
#
EXPOSE ${MJPGST_PORT}
#
ENTRYPOINT ["/init"]
