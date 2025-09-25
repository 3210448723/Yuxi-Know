vllm serve Qwen/Qwen3-Embedding-0.6B \
  --task embed \
  --dtype auto \
  --port 8000 \
  --gpu-memory-utilization 0.6