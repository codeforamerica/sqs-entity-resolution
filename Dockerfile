FROM senzing/senzingsdk-tools:latest

USER root

# Update packages and install additional dependencies.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y awscli pipx && \
    apt-get autoremove \
    && apt-get clean

# Add a new user and switch to it.
RUN useradd -m -u 1001 senzing
USER senzing

# Install awscli-local to interact with LocalStack.
ENV PATH="$PATH:/home/senzing/.local/bin"
RUN pipx install awscli-local

WORKDIR /home/senzing
