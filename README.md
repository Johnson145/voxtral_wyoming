# Voxtral Wyoming STT

Offline Speech-to-Text (STT) service using [Mistral's Voxtral](https://mistral.ai/news/voxtral) model with [Wyoming protocol](https://github.com/OHF-Voice/wyoming) compatibility for Home Assistant Assist integration.

The goal is to provide a powerful drop-in alternative to the popular Whisper STT option. Especially for non-English languages, Voxtral will hopefully set the new state of the art.

## Features

- 🔄 **Gen1 & Gen2 Models**: Supports both original Voxtral and newer Voxtral Realtime models — auto-detected at startup, just set the `MODEL_ID`
- 🎯 **Offline-only**: Local inference with Mistral's Voxtral model files (no cloud APIs)
- 🔌 **Wyoming Protocol**: Full compatibility with Home Assistant Assist
- 🐳 **Docker Ready**: Containerized deployment with non-root user
- ⚡ **Device Flexibility**: CPU, CUDA (NVIDIA), or MPS (Apple Silicon) support
- 💬 **Chat Mode** (Gen1 only): Optional chat mode with custom system prompts for domain-specific context
- 🔤 **Word Replacement**: Post-transcription word/phrase replacement to fix recurring STT mistakes

## TLDR

Run `cp .env.example .env`, configure settings, then `docker compose up --build -d`. Add as Wyoming integration in Home Assistant.


## Docker Compose Deployment (Recommended)

For easier deployment and configuration management, use Docker Compose:

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` to configure your setup:**
   ```bash
   # Edit configuration values as needed
   vim .env
   ```

See the short configuration overview below or checkout the `.env.example` for detailed documentation of all options.

3. **Start the service:**
   ```bash
   # Build and start in detached mode
   docker compose up --build -d

   # View logs
   docker compose logs -f
   ```

**GPU Support:**

To enable NVIDIA GPU support, symlink the provided override file:

```bash
ln -s docker-compose.gpu.yml docker-compose.override.yml
```

And apply changes:
```bash
docker compose up -d
```

GPU mode should get enabled automatically, but you can also do so explicitly by setting `DEVICE=cuda` in your `.env` file.

**Local Model Files:**

If you have pre-downloaded Voxtral models, uncomment the model volume mount in `docker-compose.yml`:

```yaml
volumes:
  - ./models:/models:ro
```

Then set `MODEL_ID=/models/<model_name>` in your `.env` file (e.g. `MODEL_ID=/models/Voxtral-Mini-4B-Realtime-2602`).

**Audio Saving:**

To save all received audio input as WAV files (one per transcription request), set `SAVE_AUDIO=true` in your `.env` file. The audio files will be saved to the directory specified by `AUDIO_SAVE_DIR` (default: `./output/audio/`).

The docker-compose.yml file includes a bind mount for the audio directory:

```yaml
volumes:
  - ./output/audio:/output/audio
```

Audio files are automatically saved to `./output/audio/` on your host machine with timestamp-based filenames that include the first 100 characters of the transcribed text (e.g., `audio_20251011_203145_123456_Hello_world_this_is_a_test.wav`). Special characters in the transcription are replaced with underscores for filesystem safety.

**⚠️ Warning:** Audio files may contain sensitive information. Ensure proper access controls are in place when enabling this feature.

## Docker Deployment (Alternative without Docker Compose)

### Building the Image

```bash
docker build -t voxtral-wyoming:latest .
```

#### Building on NVIDIA Spark DGX (GB10)

For NVIDIA Spark DGX systems with GB10 GPUs, use the special `Dockerfile.spark`:

```bash
docker build -f Dockerfile.spark -t voxtral-wyoming:cuda .
```

This Dockerfile uses the `nvidia/cuda:13.0.0-cudnn-devel-ubuntu24.04` base image and installs PyTorch with CUDA 13.1 support to ensure proper GB10 GPU detection.

**Running on Spark DGX:**

```bash
docker run --rm --gpus all --ipc=host \
  -p 10300:10300 \
  -v $HOME/.cache/huggingface:/home/appuser/.cache/huggingface \
  voxtral-wyoming:cuda
```

### Running the Container

```bash
# Basic run
docker run --rm -it -p 10300:10300 voxtral-wyoming:latest

# With volume mount for Voxtral model
docker run --rm -it \
  -p 10300:10300 \
  -v /path/to/voxtral/models:/models:ro \
  -e MODEL_ID=/models/Voxtral-Mini-4B-Realtime-2602 \
  voxtral-wyoming:latest

# With GPU support (NVIDIA)
docker run --rm -it --gpus all --ipc=host \
  -p 10300:10300 \
  -v /path/to/voxtral/models:/models:ro \
  -e MODEL_ID=/models/Voxtral-Mini-4B-Realtime-2602 \
  -e DEVICE=cuda \
  voxtral-wyoming:cuda
```

## Home Assistant Integration

First of all, make sure that you've started the Voxtral Wyoming server as described above.

You don't need to install any HA addon, but just configure a new Wyoming integration:

1. Click the button below (or manually go to **Settings** → **Devices & services** → **Add integration** and select **Wyoming Protocol**):

   [![Add Integration](https://my.home-assistant.io/badges/config_flow_start.svg)](https://my.home-assistant.io/redirect/config_flow_start/?domain=wyoming)

2. Enter the server host and port as configured during your server setup and confirm

3. Now you can choose `voxtral-wyoming` as the Speech-to-text option within any of your configured Assistants on **Settings** → **Voice assistants**:

   [![Voice Assistants](https://my.home-assistant.io/badges/voice_assistants.svg)](https://my.home-assistant.io/redirect/voice_assistants/)

## Configuration

All configuration is done via environment variables. The easiest way is to use a `.env` file:

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` to configure your setup:**
   ```bash
   vim .env
   ```

### Key Configuration Options

For most users, the default configuration should work just fine.

You probably want to check out at least these options, though:

- **`MODEL_ID`** - Which Voxtral model to use
  - **Gen2 (recommended):** `mistralai/Voxtral-Mini-4B-Realtime-2602` (13 languages, improved accuracy)
  - **Gen1:** `mistralai/Voxtral-Mini-3B-2507` (8 languages, smaller/faster)
  - **Gen1:** `mistralai/Voxtral-Small-24B-2507` (8 languages, larger/more accurate)
  - Or [any compatible variant from Hugging Face](https://huggingface.co/models?other=voxtral)

- **`DATA_TYPE`** - Memory/performance optimization (leave unset for auto-detection)
  - Set to `bf16` for modern GPUs (RTX 30xx+) to reduce memory usage by ~50%
  - Set to `fp16` for older GPUs with similar memory savings

- **`TRANSCRIPTION_DELAY_MS`** - Latency/accuracy trade-off (Gen2 only, ignored for Gen1; default: 480ms)
    - Lower values (e.g. `80`) are faster but less accurate; higher values (e.g. `2400`) improve accuracy at the cost of latency

- **`DEVICE`** - Which device to run the model
  - default auto selection should work fine, but you could override to `cpu`, `cuda` (NVIDIA GPU), `mps` (Apple Silicon)

- **`USE_CHAT_MODE`** - Transcription mode (default: false)
  - `false`: Optimized transcribe-only mode (faster, recommended for most users)
  - `true`: Chat mode with system prompt support for domain-specific context (Gen1 only)

- **`SYSTEM_PROMPT`** - Custom instructions for chat mode (Gen1 only, requires `USE_CHAT_MODE=true`)
  - Customize to guide transcription for smart home commands or specific vocabulary
  - Should be in the language you expect to speak

- **`WORD_REPLACEMENTS`** / **`WORD_REPLACEMENTS_FILE`** - Fix recurring STT mistakes by replacing words/phrases after transcription (e.g. `schaltet -> schalte`). Docker Compose users can simply edit `word_replacements.txt`.

For all available configuration options, see `.env.example` with detailed documentation.

## Development

### Installation (Development)

```bash
uv venv
source .venv/bin/activate
uv sync
```

Requires Python and uv to be installed.

### Running the Server (Development)

```bash
# Use default .env file
voxtral-wyoming

# Or specify a custom environment file
voxtral-wyoming /path/to/custom.env

# Or use environment variables directly
HOST=0.0.0.0 PORT=10300 LANGUAGE_FALLBACK=en-US voxtral-wyoming
```

All configuration is done via environment variables loaded from a `.env` file (default) or a custom environment file specified as the only command-line argument.

### Testing with Sample Audio

Use the example client to test transcription:

```bash
# Use default .env file
python examples/client_sample.py

# Or specify a custom environment file
python examples/client_sample.py /path/to/custom.env

# Or override SAMPLE_FILE directly (local path or remote URL)
SAMPLE_FILE=test-audio/my_recording.wav python examples/client_sample.py
SAMPLE_FILE=https://example.com/audio.mp3 python examples/client_sample.py
```

`SAMPLE_FILE` accepts both local file paths (absolute or relative) and remote URLs (http/https). When not set, it defaults to a public sample hosted on Hugging Face.

The sample client will automatically attempt to convert audio to PCM16 mono using ffmpeg if available and enabled. Note: The server expects PCM16 mono audio at 16kHz as per the Wyoming protocol standard.

## Updating to a New Version

### Docker Compose (Recommended)

To update to the latest version:

```bash
# Pull the latest changes
git pull

# Rebuild and restart
docker compose up --build -d

# View logs to verify the update
docker compose logs -f
```

### Docker (without Docker Compose)

```bash
# Pull the latest changes
git pull

# Rebuild the image
docker build -t voxtral-wyoming:latest .

# Stop and remove the old container
docker stop <container_name>
docker rm <container_name>

# Start the new container with your existing configuration
docker run --rm -it -p 10300:10300 voxtral-wyoming:latest
```

### Development Installation

```bash
# Pull the latest changes
git pull

# Activate your virtual environment
source .venv/bin/activate

# Update dependencies
uv sync

# Restart the server
voxtral-wyoming
```

**Note:** After updating, you may need to:
- Review `.env.example` for new configuration options and update your `.env` file accordingly


## Troubleshooting

### voxtral-wyoming exited with code 137
The server process probably got killed by your OS or the docker engine as it was using too many resources. If you
are using the dockerized version, you can try to use the python variant directly. Otherwise, you probably need to
change settings on your local setup.

### Model Not Found

If you see "model not found" errors:
1. Ensure `MODEL_ID` points to a valid model id from Hugging Face
2. Or ensure the model is in your HuggingFace cache (run `huggingface-cli download mistralai/Voxtral-Mini-4B-Realtime-2602`)


### GPU Not Working

If CUDA/GPU is not detected:
1. Ensure NVIDIA drivers and CUDA toolkit are installed
2. Ensure PyTorch with CUDA support is installed: `pip install torch --index-url https://download.pytorch.org/whl/cu121`
3. Check GPU availability: `python -c "import torch; print(torch.cuda.is_available())"`
4. The server will automatically fall back to CPU if GPU initialization fails

#### Spark DGX (GB10) GPU Troubleshooting

For Spark DGX systems with GB10 GPUs:
1. Use `Dockerfile.spark` instead of the default `Dockerfile`
2. Ensure you're using `--gpus all` flag when running the container
3. Check that NVIDIA Container Toolkit is configured: `docker info | grep -i runtime`
4. Verify GPU detection: `docker run --rm --gpus all voxtral-wyoming:cuda python -c "import torch; print(torch.cuda.get_device_name(0))"`

### CUDA Compute Capability Error

If you see an error like:
```
Found GPU0 NVIDIA GeForce GTX 1070 which is of cuda capability 6.1.
Minimum and Maximum cuda capability supported by this version of PyTorch is (7.0) - (12.0)
```

This means your GPU is too old for the installed PyTorch version. **Solution:**

1. **Check your PyTorch version:**
   ```bash
   python -c "import torch; print(torch.__version__)"
   ```

2. **If using PyTorch 2.8 or newer**, you need to downgrade to PyTorch 2.5 or earlier (which support CUDA compute capability 6.1):

   **For pip installations:**
   ```bash
   pip install 'torch>=2.4.0,<2.6.0' --index-url https://download.pytorch.org/whl/cu121
   ```

   **For uv installations:**
   ```bash
   uv pip install 'torch>=2.4.0,<2.6.0'
   ```

3. **For Docker users**, rebuild the image after ensuring `pyproject.toml` has the correct PyTorch version constraint:
   ```bash
   docker compose up --build -d
   ```

### Connection Issues with Home Assistant

If Home Assistant can't connect:
1. Ensure the server is running and listening on the correct host/port
2. Check firewall settings (port 10300 must be accessible)
3. Verify network connectivity between Home Assistant and the server
4. Check server logs for connection attempts

## Hardware & Performance
Running Voxtral is relatively hardware-intensive. It is highly recommended to use a GPU with at least 10GB VRAM for optimal performance. It also does not need to be the latest top model, though.

Personally, I'm currently using a RTX 3090. Having reduced memory requirements by setting `DATA_TYPE=bf16`, most gen1 (`MODEL_ID=/models/Voxtral-Mini-3B-2507`) STT requests are handled in ~0.5s while using ~9GB VRAM.
In contrast, my Apple M2 Max needs ca. 5 seconds per request (same config, similar RAM requirement).

Check out the `DATA_TYPE` parameter, if you're having memory troubles.

I can't really recommend running the model on CPU only. Anyway, if you want to give it a shot, I suggest using one of the _quantized_ models ([gen1](https://huggingface.co/models?other=base_model:quantized:mistralai/Voxtral-Mini-3B-2507) or [gen2](https://huggingface.co/models?other=base_model:quantized:mistralai/Voxtral-Mini-4B-Realtime-2602)) for the `MODEL_ID` option to further reduce required resources.


## Online Alternative
If you do not want to host Voxtral on your own, but rather use Mistral's online API, [ha-openai-whisper-stt-api is a nice HA addon provided by fabio-garavini](https://github.com/fabio-garavini/ha-openai-whisper-stt-api).

## Contributing
Contributions are welcome!
