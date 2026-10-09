# Werkomgeving voor de CPU Design Cursus: simuleren, FPGA-synthese en het boek bouwen.
FROM mcr.microsoft.com/devcontainers/base:trixie

# Icarus Verilog (simulatie), Python (assemblers en tests), pandoc (build.py) en gh (GitHub)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
       iverilog python3 python3-venv make \
       pandoc gh curl xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Typst zet het boek (build.py). De versie ligt vast, zodat de opmaak niet verschuift.
ARG TYPST_VERSION=0.15.1
RUN arch=$(uname -m) \
    && curl -fsSL https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${arch}-unknown-linux-musl.tar.xz \
    | tar -xJ -C /usr/local/bin --strip-components=1 typst-${arch}-unknown-linux-musl/typst

# Yosys en nextpnr als YoWASP-pakketten in ~/fpga-venv, zoals week 23 beschrijft.
# De scripts van week 23, 24, 26 en 30 vinden ze daar vanzelf. De versies liggen vast,
# zodat de getallen in week 24 (LC's, MHz) dezelfde blijven.
USER vscode
RUN python3 -m venv /home/vscode/fpga-venv \
    && /home/vscode/fpga-venv/bin/pip install --no-cache-dir --quiet \
       yowasp-yosys==0.69.0.0.post1233 yowasp-nextpnr-ice40==0.11.1.0.post826
