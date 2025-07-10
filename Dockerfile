FROM ubuntu:jammy

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV LANG en_US.UTF-8
ARG TARGETARCH

# Instalar dependencias del sistema
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        npm \
        git \
        python3-dev \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        python3-psycopg2 \
        python3-ldap \
        libldap2-dev \
        libsasl2-dev \
        ldap-utils \
        tox \
        lcov \
        valgrind \
        gcc \
        build-essential \
        python3-gevent \
        xz-utils && \
    if [ -z "${TARGETARCH}" ]; then \
        TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac && \
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb && \
    echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - && \
    apt-get install -y --no-install-recommends ./wkhtmltox.deb && \
    rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# PostgreSQL client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list && \
    GNUPGHOME="$(mktemp -d)" && \
    export GNUPGHOME && \
    repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' && \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" && \
    gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc && \
    gpgconf --kill all && \
    rm -rf "$GNUPGHOME" && \
    apt-get update && \
    apt-get install --no-install-recommends -y postgresql-client && \
    rm -f /etc/apt/sources.list.d/pgdg.list && \
    rm -rf /var/lib/apt/lists/*

# RTL CSS
RUN npm install -g rtlcss

# Crear usuario y estructura de Odoo
RUN adduser --disabled-password --home /opt/odoo --gecos '' odoo
RUN mkdir /etc/odoo && mkdir /tmp/odoo/

# Clonar Odoo 18 Community
RUN git clone --depth=1 --branch=18.0 https://github.com/odoo/odoo.git /opt/odoo/server
RUN pip3 install --upgrade pip
RUN cd /opt/odoo/server && pip3 install -r requirements.txt

# Instalar dependencias adicionales para localización ecuatoriana
RUN pip3 install xmlsig cryptography lxml zeep python-barcode

# Clonar localización ecuatoriana oficial de OCA
RUN mkdir -p /mnt/extra-addons && \
    git clone --depth=1 --branch=18.0 https://github.com/OCA/l10n-ecuador /mnt/extra-addons/l10n-ecuador

# Copiar archivos de configuración
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Permisos
RUN chmod +x /entrypoint.sh && \
    chown odoo /etc/odoo/odoo.conf && \
    mkdir -p /var/lib/odoo && \
    chown -R odoo /mnt/extra-addons /var/lib/odoo

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Alias para ejecutar odoo-bin
RUN ln -s /opt/odoo/server/odoo-bin /usr/bin/odoo-bin

EXPOSE 8069

ENV ODOO_RC /etc/odoo/odoo.conf

USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo-bin"]