# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu22.04 AS base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Install comfy-cli
RUN uv pip install comfy-cli --system

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --version 0.3.30 --cuda-version 12.6 --nvidia

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client --system

# Add application code and scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

# Set the default command to run when starting the container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base AS downloader

# Install git if not available from base
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

ARG HUGGINGFACE_ACCESS_TOKEN

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories upfront
RUN mkdir -p models/checkpoints models/vae models/unet models/clip models/loras models/upscale_models

# Download checkpoints/vae/unet/clip models to include in image
RUN wget -q --header="Authorization: Bearer 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" -O models/unet/flux1-dev.safetensors https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors && \
    wget -q -O models/clip/clip_l.safetensors https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors && \
    wget -q -O models/clip/t5xxl_fp8_e4m3fn.safetensors https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors && \
    wget -q --header="Authorization: Bearer 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" -O models/vae/ae.safetensors https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors && \
    wget -q -O models/loras/amateur_photography.safetensors https://mnxqwavpoeqffejselct.supabase.co/storage/v1/object/public/temp/default/Amateur%20Photo%20v6.safetensors && \
    wget -q -O models/loras/canopus_flux_ultrarealism.safetensors https://ktwcktilecskgbzmmfbq.supabase.co/storage/v1/object/public/temp/default/Canopus%20LoRA%20Flux%20UltraRealism%202.0.safetensors && \
    wget -q -O models/upscale_models/4x_face_up_dat.pth https://ktwcktilecskgbzmmfbq.supabase.co/storage/v1/object/public/temp/default/4x%20Face%20Up%20DAT.pth
    
# Install custom nodes
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale && \
    git clone https://github.com/glifxyz/ComfyUI-GlifNodes && \
    git clone https://github.com/rgthree/rgthree-comfy

# Stage 3: Final image
FROM base AS final

# Install same Python dependencies in final image
RUN uv pip install diffusers accelerate omegaconf opencv-python --system

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models
# Copy custom nodes from stage 2 to the final image
COPY --from=downloader /comfyui/custom_nodes /comfyui/custom_nodes
