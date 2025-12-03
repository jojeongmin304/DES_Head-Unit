#
# Instrument cluster CAN setup:
#  - SPI + I2C stay enabled so the controller stack can talk to the CAN HW.
#  - CAN overlays: upstream MCP251xfd on SPI0-0 and SPI1-0 (dual bus via spi1-3cs).
#

ENABLE_SPI_BUS = "1"
ENABLE_I2C = "1"


# GPU Memory Configuration (optimized for dual display with power efficiency)
GPU_MEM = "128"

# Enable psplash boot logo support
ENABLE_UART = "1"

# Override VC4 dtoverlay to include noaudio parameter (prevents duplication)
VC4DTBO = "vc4-kms-v3d,noaudio"

# Dual HDMI Display Configuration for Head-Unit and Instrument Cluster
# HDMI-0: Head-Unit (1024x600), HDMI-1: Instrument Cluster (1024x600)
RPI_EXTRA_CONFIG:append = "\
\ndtoverlay=spi1-3cs\
\ndtoverlay=mcp251xfd,spi0-0,oscillator=40000000,interrupt=25\
\ndtoverlay=mcp251xfd,spi1-0,oscillator=40000000,interrupt=24\
\nhdmi_drive:0=2\
\nhdmi_drive:1=2\
\nhdmi_force_hotplug:0=1\
\nhdmi_force_hotplug:1=1\
\nhdmi_group:0=2\
\nhdmi_group:1=2\
\nhdmi_mode:0=87\
\nhdmi_mode:1=87\
\nhdmi_cvt:0=1024 600 60 6 0 0 0\
\nhdmi_cvt:1=1024 600 60 6 0 0 0\
\nconfig_hdmi_boost:0=2\
\nconfig_hdmi_boost:1=2\
\ndisable_overscan=1\
\nmax_framebuffers=2\
\nenable_uart=1\
\ndisable_splash=1\
\n"
