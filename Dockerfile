# Parent image
FROM redhat/ubi9:9.4

LABEL description="HuBMAP API Docker Base Image, Python 3.13 for uwsgi apps"

WORKDIR /tmp

# Stick a shell script into the image which does verification of the
# configuration commands which follow.
COPY ./verify_install.sh .
RUN chmod 755 ./verify_install.sh

# When trying to run "update" or "install" commands using dnf or yum the
# "system is not registered with an entitlement server" error message is given.
# Avoid subscription-manager entitlement errors by configuring the subscription manager:
RUN set -eux && \
    cat <<EOF > /etc/dnf/plugins/subscription-manager.conf
[main]
enabled=0
# When following option is set to 1, then all repositories defined outside redhat.repo will be disabled
# every time subscription-manager plugin is triggered by dnf or yum
disable_system_repos=0
EOF

# Reduce the number of layers in image by minimizing the number of separate RUN commands
# 1 - Install GCC, Git, Python 3.13, libraries needed for Python development, and pcre needed by uwsgi
# 2 - Set default Python version for `python` and `python3` commands.
#     N.B. Leave the Python native to the UBI for
#          system utilities like `dnf` and `yum` in
#          place at /usr/libexec/platform-python.
# 3 - Ensure pip is available, upgraded, and aliased 
# 4 - Pip install wheel and uwsgi packages globally using pip3.13. Pip uses wheel to install uwsgi
# 5 - Build and install su-exec for privilege drop
# 6 - Remove apps not needed in image, clean up yum cache to reduce size and vulnerabilities

# Install OS packages needed for the rest of this configuration and for
# operations while running services in uWSGI.
RUN set -eux && \
    dnf upgrade --assumeyes && \
    dnf install --assumeyes dnf-plugins-core && \
    dnf install --assumeyes gcc git && \
    dnf install --assumeyes make wget openssl-devel bzip2-devel libffi-devel && \
    dnf install --assumeyes zlib-devel xz-devel procps-ng && \
    dnf clean all 

# Install using Python 3.13 and the packages needed for services to run in uWSGI
RUN set -eux && \
    cd /usr/local/src && \
    wget https://www.python.org/ftp/python/3.13.9/Python-3.13.9.tgz && \
    tar xzf Python-3.13.9.tgz && \
    cd Python-3.13.9 && \
    ./configure --enable-optimizations --prefix=/usr/local/python3.13 && \
    make -j$(nproc) && make altinstall && \
    ln -sf /usr/local/python3.13/bin/pip3.13 /usr/local/bin/pip3.13 && \
    ln -sf /usr/local/python3.13/bin/python3.13 /usr/local/bin/python3.13 && \
    wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    dnf install --assumeyes ./epel-release-latest-9.noarch.rpm && \
    dnf config-manager --set-disabled epel && \
    dnf install --assumeyes --enablerepo=epel python3.13-devel && \
    /usr/local/bin/pip3.13 install --root-user-action=ignore --no-cache-dir --upgrade pip wheel uwsgi && \
    rm -rf /usr/local/src/Python-3.13.9*

# Register Python 3.13 with 'alternatives' so that it has higher
# priority than the system default.  Also make sure it is aliased as
# 'python3' for shell users by via a uwsgi-affiliated script.
RUN set -eux && \
    alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 10 && \
    alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.13 20 && \
    # make 'python3' point to 3.13 only for uwsgi and app processes && \
    echo 'alias python3=/usr/local/bin/python3.13' >> /etc/profile.d/uwsgi_python.sh && \
    echo 'alias python=/usr/local/bin/python3.13' >> /etc/profile.d/uwsgi_python.sh && \
    echo 'alias pip3=/usr/local/bin/pip3.13' >> /etc/profile.d/uwsgi_python.sh && \
    echo 'alias pip=/usr/local/bin/pip3.13' >> /etc/profile.d/uwsgi_python.sh

# Install su-exec for de-elevating root to hive user while running services, and
# remove packages which were only needed by the preceding steps and not by
# services running in uWSGI.
RUN set -eux && \
    dnf install --assumeyes procps-ng make && \
    git clone https://github.com/ncopa/su-exec.git /tmp/su-exec && \
    cd su-exec && \
    make && \
    mv su-exec /usr/local/bin/ && \
    chmod a+x /usr/local/bin/su-exec && \
    cd /tmp && \
    rm -Rf /tmp/su-exec/ && \
    # N.B. git and gcc are needed for su-exec installation, but
    #      also must remain for uwsgi, so do not remove like
    #      compilation-only packages.
    dnf remove --assumeyes make wget && \
    dnf clean all
