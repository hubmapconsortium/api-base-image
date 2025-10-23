# Parent image
FROM redhat/ubi10:latest

LABEL description="HuBMAP API Docker Base Image, Python 3.13 for uwsgi apps"

WORKDIR /tmp

# Stick a shell script into the image which does verification of the
# configuration commands which follow.
COPY ./verify_install.sh .
RUN chmod 755 ./verify_install.sh

# Stick a shell script in the image which verifies the system Python version is
# still available, but uWSGI runs with Python 3.13.
COPY ./verify_uwsgi.sh .
RUN chmod 755 ./verify_uwsgi.sh

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

# Configure global dnf behavior to disable installation of weak dependencies and
# documentation globally to minimize image size, while preserving Red Hat defaults that
# help avoid breakage when upgrading packages.
# Configure global DNF behavior for smaller image layers
RUN set -eux && \
    cat <<'EOF' > /etc/dnf/dnf.conf
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
skip_if_unavailable=True
install_weak_deps=False
tsflags=nodocs
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
# Install using Python 3.13 and the packages needed for services to run in uWSGI
RUN set -eux && \
    # Install what is needed to retrieve and build Python for uWSGI, and to execute uWSGI
    dnf upgrade --assumeyes && \
    dnf install --assumeyes dnf-plugins-core && \
    dnf install --assumeyes gcc && \
    dnf install --assumeyes make wget openssl-devel bzip2-devel libffi-devel && \
    dnf install --assumeyes zlib-devel xz-devel procps-ng && \
    cd /usr/local/src && \
    wget https://www.python.org/ftp/python/3.13.9/Python-3.13.9.tgz && \
    tar xzf Python-3.13.9.tgz && \
    cd Python-3.13.9 && \
    # Use --without-ensurepip to disable test suite installation, but
    # then manually install pip using get-pip.py.
    ./configure --enable-optimizations \
                --without-ensurepip \
		--without-tests \
		--prefix=/usr/local/python3.13 && \
    make -j$(nproc) && \
    make altinstall && \
    make clean && \
    # Remove debug symbols from Python 3.13
    strip /usr/local/python3.13/bin/python3.13 && \
    # Manually install pip
    wget https://bootstrap.pypa.io/get-pip.py && \
    /usr/local/python3.13/bin/python3.13 get-pip.py && \
    # Soft link the Python for uWSGI to a location in the typical
    # PATH, and next do the system Python used by dnf.
    ln -sf /usr/local/python3.13/bin/python3.13 /usr/local/bin/python3.13 && \
    ln -sf /usr/local/python3.13/bin/pip3.13 /usr/local/bin/pip3.13 && \
    # Add the Extra Packages for Enterprise Linux repository while python3.13-devel is not
    # available in the standard UBI 10 base AppStream repository
    wget --quiet https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm && \
    dnf install --assumeyes ./epel-release-latest-10.noarch.rpm && \
    dnf install --assumeyes --enablerepo=epel python3.13-devel && \
    # Install the Python package the services need to run uWSGI, and its dependencies
    /usr/local/bin/pip3.13 install --root-user-action=ignore --no-cache-dir --upgrade pip wheel uwsgi && \
    # Empty out the __pycache__ directories of new Python installation to minimize the size of
    # this Image layer.  Expect running Containers to refill as they start Python
    find /usr/local/python3.13 -type d -name '__pycache__' -exec rm -rf {} + && \
    # Remove the EPEL repo and clean up other artifacts to slim down this layer of the Docker Image
    dnf remove --assumeyes epel-release && \
    dnf remove --assumeyes make wget gcc && \
    dnf remove --assumeyes python-devel openssl-devel bzip2-devel libffi-devel zlib-devel xz-devel procps-ng && \
    dnf autoremove --assumeyes && \
    dnf clean all && \
    rm -f /etc/yum.repos.d/epel*.repo && \
    rm -rf /usr/local/src/Python-3.13.9* \
           /usr/local/python3.13/lib/python3.13/test \
           /usr/local/python3.13/lib/python3.13/ensurepip \
           /var/cache/dnf \
           /var/log/dnf \
           /var/log/yum \
	   /root/.cache

# Register Python 3.13 with 'alternatives' so that it has higher
# priority than the system default.  Also make sure it is aliased as
# 'python3' for shell users by via a uwsgi-affiliated script.
RUN set -eux && \
    # Keep system python (3.12) as default for dnf/yum
    alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 20 && \
    # Register python3.13, but lower priority so it's not the default
    alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.13 10 && \
    # make 'python3' point to 3.13 using aliases only for uwsgi and app shells && \
    echo 'alias python3=/usr/local/bin/python3.13' >> /etc/profile.d/uwsgi_python.sh && \
    echo 'alias python=/usr/local/bin/python3.13' >> /etc/profile.d/uwsgi_python.sh && \
    echo 'alias pip3=/usr/local/bin/pip3.13' >> /etc/profile.d/uwsgi_python.sh && \
    echo 'alias pip=/usr/local/bin/pip3.13' >> /etc/profile.d/uwsgi_python.sh

# Install su-exec for de-elevating root to hive user while running services, and
# remove packages which were only needed by the preceding steps and not by
# services running in uWSGI.
RUN set -eux && \
    # Install what is needed to retrieve and build su-exec
    dnf install --assumeyes procps-ng make gcc git wget && \
    # Fetch the latest commit without any history
    git clone --depth 1 https://github.com/ncopa/su-exec.git /tmp/su-exec && \
    # Build and install su-exec
    make -C /tmp/su-exec && \
    install -m 755 /tmp/su-exec/su-exec /usr/local/bin/su-exec && \
    # Clean up artifacts to slim down this layer of the Docker Image
    dnf remove --assumeyes procps-ng make gcc git wget && \
    dnf autoremove --assumeyes && \
    dnf clean all && \
    rm -rf /tmp/su-exec \
           /var/cache/dnf \
           /var/log/dnf \
           /var/log/yum \
	   /root/.cache
