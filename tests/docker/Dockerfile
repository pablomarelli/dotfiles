FROM ubuntu:24.04

ARG USERNAME=sandbox

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/$USERNAME

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        gosu \
        sudo \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

RUN curl -fsLS https://get.chezmoi.io | sh -s -- -b /usr/local/bin

RUN mkdir -p /home/$USERNAME/.config/chezmoi

COPY tests/chezmoi.linux-test.toml /home/$USERNAME/.config/chezmoi/chezmoi.toml
COPY tests/docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chown -R $USERNAME:$USERNAME /home/$USERNAME/.config \
    && chmod +x /usr/local/bin/entrypoint.sh

USER $USERNAME
WORKDIR /home/$USERNAME

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
