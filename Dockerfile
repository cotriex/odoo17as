FROM ubuntu:jammy

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV LANG en_US.UTF-8
ARG TARGETARCH

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl dirmngr fonts-noto-cjk gnupg \
        libssl-dev node-less npm git python3-dev python3-magic \
        python3-num2words python3-odf python3-pdfminer python3-pip \
        python3-phonenumbers python3-pyldap python3-qrcode python3-renderpm \
        python3-setuptools python3-slugify python3-vobject python3-watchdog \
        python3-xlrd python3-xlwt python3-psycopg2 python3-ldap \
        libldap2-dev libsasl2-dev ldap-utils tox lcov valgrind gcc \
        build-essential python3-gevent xz-utils && \
    TARGETARCH=${TARGETARCH:-$(dpkg --print-architecture)} && \
    case ${TARGETARCH} in \
      amd64) WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59 ;; \
      arm64) WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc ;; \
    esac && \
    curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${TARGETARCH}.deb && \
    echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - && \
    apt-get install -y ./wkhtmltox.deb && rm -f wkhtmltox.deb && \
    rm -rf /var/lib/apt/lists/*

# PostgreSQL client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list && \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8 && \
    gpg --batch --armor --export B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8 > /etc/apt/trusted.gpg.d/pgdg.gpg.asc && \
    apt-get update && apt-get install -y postgresql-client && \
    rm -f /etc/apt/sources.list.d/pgdg.list && rm -rf /var/lib/apt/lists/*

RUN npm install -g rtlcss

RUN adduser --disabled-password --home /opt/odoo --gecos '' odoo && \
    mkdir -p /etc/odoo /tmp/odoo /mnt/extra-addons

RUN git clone --depth=1 --branch=18.0 https://github.com/odoo/odoo.git /opt/odoo/server && \
    pip3 install --upgrade pip && \
    pip3 install -r /opt/odoo/server/requirements.txt && \
    pip3 install xmlsig cryptography lxml zeep python-barcode

# OCA Localización Ecuador 17.0 (adaptar a 18.0)
RUN git clone --depth=1 --branch=17.0 https://github.com/OCA/l10n-ecuador /mnt/extra-addons/l10n-ecuador-17 && \
    find /mnt/extra-addons/l10n-ecuador-17 -name '__manifest__.py' -exec sed -i 's/\"17.0\"/\"18.0\"/' {} +

COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

RUN chmod +x /entrypoint.sh && \
    chown -R odoo /etc/odoo /mnt/extra-addons /var/lib/odoo

VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]
RUN ln -s /opt/odoo/server/odoo-bin /usr/bin/odoo-bin
EXPOSE 8069
ENV ODOO_RC=/etc/odoo/odoo.conf
USER odoo
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo-bin"]