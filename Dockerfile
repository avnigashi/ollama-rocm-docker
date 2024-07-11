# Dockerfile
FROM rocm/dev-ubuntu-20.04:4.3-complete

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables for ROCm
ENV ROCM_PATH=/opt/rocm
ENV PATH=$ROCM_PATH/bin:$PATH
ENV LD_LIBRARY_PATH=$ROCM_PATH/lib:$LD_LIBRARY_PATH

# Clone Ollama source code
RUN git clone https://github.com/your-ollama-repo-url /ollama
WORKDIR /ollama

# Install Python dependencies
RUN pip3 install -r requirements.txt

# Expose necessary ports (if any)
EXPOSE 8080

# Run Ollama
CMD ["python3", "run_ollama.py"]
