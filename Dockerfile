# start from a clean base image
FROM runpod/worker-comfyui:5.0.1-base

# install custom nodes using comfy-cli
RUN comfy node install ComfyUI_UltimateSDUpscale 

# download Flux models
RUN comfy model download --url https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors --relative-path models/unet --filename flux1-dev.safetensors && \
    comfy model download --url https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors --relative-path models/clip --filename clip_l.safetensors && \
    comfy model download --url https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors --relative-path models/clip --filename t5xxl_fp8_e4m3fn.safetensors && \
    comfy model download --url https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors --relative-path models/vae --filename ae.safetensors
