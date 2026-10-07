# Werkomgeving voor de CPU Design Cursus: simuleren, FPGA-synthese en de PDF's bouwen.
FROM mcr.microsoft.com/devcontainers/base:trixie

# Icarus Verilog (simulatie), Python (assemblers en tests), pandoc en Chromium (build.sh)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
       iverilog python3 python3-venv make \
       pandoc chromium fonts-dejavu fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

# Yosys en nextpnr als YoWASP-pakketten in ~/fpga-venv, zoals week 23 beschrijft.
# De scripts van week 23, 24, 26 en 30 vinden ze daar vanzelf. De versies liggen vast,
# zodat de getallen in week 24 (LC's, MHz) dezelfde blijven.
USER vscode
RUN python3 -m venv /home/vscode/fpga-venv \
    && /home/vscode/fpga-venv/bin/pip install --no-cache-dir --quiet \
       yowasp-yosys==0.69.0.0.post1233 yowasp-nextpnr-ice40==0.11.1.0.post826
