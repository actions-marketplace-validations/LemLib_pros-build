# ------------
# Build Stage: Get Dependencies
# ------------
FROM alpine:latest AS get-dependencies
LABEL stage=builder

LABEL org.opencontainers.image.description="A PROS Build Container"
LABEL org.opencontainers.image.source=https://github.com/lemlib/pros-build
LABEL org.opencontainers.image.licenses=MIT

ENV TOOLCHAIN_VERSION=14.3.1
ENV TOOLCHAIN_VERSION_WITH_REL=14.3.rel1

# Install Required Packages and ARM Toolchain
RUN apk add --no-cache bash
RUN mkdir "/arm-none-eabi-toolchain" && wget -O- "https://developer.arm.com/-/media/Files/downloads/gnu/$TOOLCHAIN_VERSION_WITH_REL/binrel/arm-gnu-toolchain-$TOOLCHAIN_VERSION_WITH_REL-x86_64-arm-none-eabi.tar.xz" \
    | tar Jxf - -C "/arm-none-eabi-toolchain" --strip-components=1 
RUN <<-"EOF" bash
    set -e

    toolchain="/arm-none-eabi-toolchain"
    mkdir -p "$toolchain"

    rm -rf "$toolchain"/{share,include}
    rm -rf "$toolchain"/lib/gcc/arm-none-eabi/"$TOOLCHAIN_VERSION"/arm
    rm -f "$toolchain"/bin/arm-none-eabi-{gdb,gdb-py,cpp,gcc-"$TOOLCHAIN_VERSION"}
    
    find "$toolchain"/arm-none-eabi/lib/thumb                                               -mindepth 1 -maxdepth 1 ! -name 'v7-a+simd' -exec rm -rf {} +
    find "$toolchain"/lib/gcc/arm-none-eabi/"$TOOLCHAIN_VERSION"/thumb                      -mindepth 1 -maxdepth 1 ! -name 'v7-a+simd' -exec rm -rf {} +
    find "$toolchain"/arm-none-eabi/include/c++/"$TOOLCHAIN_VERSION"/arm-none-eabi/thumb    -mindepth 1 -maxdepth 1 ! -name 'v7-a+simd' -exec rm -rf {} + 

    apk cache clean # Cleanup image
EOF
# ------------
# Runner Stage
# ------------
FROM alpine:latest AS runner
LABEL stage=runner
LABEL org.opencontainers.image.description="A PROS Build Container"
LABEL org.opencontainers.image.source=https://github.com/lemlib/pros-build
LABEL org.opencontainers.image.licenses=MIT
# Copy dependencies from get-dependencies stage
COPY --from=get-dependencies /arm-none-eabi-toolchain /arm-none-eabi-toolchain
RUN apk add --no-cache gcompat libc6-compat libstdc++ git gawk python3 pipx make unzip bash && pipx install pros-cli --preinstall "setuptools<81" && apk cache clean

# Set Environment Variables
ENV PATH="/arm-none-eabi-toolchain/bin:/root/.local/bin:${PATH}"
# Silences warning when running pros about using setuptools<81
ENV PYTHONWARNINGS="ignore::UserWarning"

# Setup Build
ENV PROS_PROJECT=${PROS_PROJECT}
ENV REPOSITORY=${REPOSITORY}
ENV LIBRARY_PATH=${LIBRARY_PATH}

COPY build-tools/build.sh /build.sh
RUN chmod +x /build.sh
COPY LICENSE ./LICENSE

ENTRYPOINT ["/build.sh"]
