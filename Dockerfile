# Use the Kubeflow Code-Server Python image
FROM kubeflownotebookswg/codeserver-python:latest

# Switch to root to make modifications
USER root

# Remove code-server completely
RUN apt-get remove -y code-server \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /etc/services.d/code-server \
    && rm -rf /usr/lib/code-server \
    && rm -rf /usr/bin/code-server \
    && rm -rf ${HOME}/.local/share/code-server \
    && rm -rf ${HOME_TMP}/.local/share/code-server

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libgomp1 \
    curl \
    wget \
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 02-conda-init /etc/cont-init.d/02-conda-init
COPY --chmod=755 03-build-front-init /etc/cont-init.d/03-build-front-init

ARG GITHUB_PAT

# Clone Open WebUI repository to tmp_home (which will be copied to home at runtime)
RUN git clone https://${GITHUB_PAT}@github.com/DrJonnyMoney/open-webui-vite.git /tmp_home/jovyan/open-webui-vite

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

RUN chown -R ${NB_USER}:${NB_GID} /tmp_home/jovyan/

# Create .fend file with BUILD_FRONTEND flag
RUN echo 'export BUILD_FRONTEND="false"' > /tmp_home/jovyan/.fend \
    && chmod 755 /tmp_home/jovyan/.fend

# Switch to the notebook user (if not already)
USER $NB_UID

# Install NVM for the notebook user
ENV NVM_DIR /tmp_home/jovyan/.nvm
RUN mkdir -p $NVM_DIR \
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash \
    && echo 'export NVM_DIR="/tmp_home/jovyan/.nvm"' >> /tmp_home/jovyan/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm' >> /tmp_home/jovyan/.bashrc

# Load nvm and install the specified Node version; set it as default
RUN . $NVM_DIR/nvm.sh \
    && nvm install 20 \
    && nvm alias default 20

# Ensure the Node.js binary directory is in PATH for future shells
RUN echo 'export PATH="/tmp_home/jovyan/.nvm/versions/node/v20.*/bin:$PATH"' >> /tmp_home/jovyan/.bashrc

# Install global npm packages for Svelte development (e.g., SvelteKit and Vite)
RUN bash -c "source /tmp_home/jovyan/.nvm/nvm.sh && npm install -g @sveltejs/kit vite"


USER root

COPY ollama-run /etc/services.d/ollama/run
RUN chmod 755 /etc/services.d/ollama/run && \
    chown ${NB_USER}:${NB_GID} /etc/services.d/ollama/run

COPY open-webui-run /etc/services.d/open-webui/run
RUN chmod 755 /etc/services.d/open-webui/run && \
    chown ${NB_USER}:${NB_GID} /etc/services.d/open-webui/run

# Expose port 8888
EXPOSE 8888
# Switch back to non-root user
USER $NB_UID
# Keep the original entrypoint
ENTRYPOINT ["/init"]
