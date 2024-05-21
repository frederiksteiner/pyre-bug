ARG BASE_VERSION=8.9
FROM registry.access.redhat.com/ubi8/ubi:${BASE_VERSION}

ARG BASH_FILE_PATH="/root/.bashrc"
ENV PROFILE="$BASH_FILE_PATH"

ARG BRANCH_VERSION
ENV IMAGE_VERSION=${BRANCH_VERSION}

ARG PYTHON_VERSIONS="3.11.9"

RUN dnf clean all \
    && dnf --exclude=shadow-utils update -y \
    && dnf install zlib-devel bzip2 bzip2-devel sqlite sqlite-devel openssl-devel libffi-devel xz-devel libpq-devel python3-devel git gcc gcc-c++ make automake autoconf libtool -y \
    && dnf clean all \
    && rm -fr /var/cache/yum/*

# Add PYENV and Poetry to the path
ENV HOME="/root"
ENV CPPFLAGS=-I/usr/include/openssl
ENV LDFLAGS=-L/usr/lib64
ENV PYENV_ROOT="$HOME/.pyenv"
ENV POETRY_HOME=/etc/poetry
ENV PATH="$PYENV_ROOT/bin:$POETRY_HOME/bin:$PATH"
ENV POETRY_VERSION="1.8.3"

# Install PYENV
RUN curl https://pyenv.run | bash \
    && eval "$(pyenv init -)"

COPY . ./
# Manually add shims to path to enable pyenv in all shells.
ENV PATH=$PYENV_ROOT/shims:$PATH


# Install Python versions and Poetry
RUN \
    IFS=' ' read -ra PYENV_VERSION <<<"$PYTHON_VERSIONS" \
    && for version in $PYTHON_VERSIONS; do pyenv install $version; done \
    && eval "$(pyenv init -)" \
    && for version in `pyenv versions --bare`; do PYENV_VERSION=$version python -m pip install --upgrade pip dunamai; done \
    && pyenv global $PYENV_VERSION \
    && echo -e "Installed Python versions:\n$(pyenv versions)" \
    && echo "Default Python version: $(pyenv version)" \
    && curl -sSL https://install.python-poetry.org | python - \
    && echo -e "\n\n# pyenv setup" >> "$PROFILE" \
    && echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> "$PROFILE" \
    && echo 'eval "$(pyenv init -)"' >> "$PROFILE" \
    && poetry install --all-extras \
    && poetry run pyre --noninteractive --debug --sequential check
