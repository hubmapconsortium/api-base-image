# Parent image
FROM redhat/ubi9:9.4

LABEL description="HuBMAP API Docker Base Image"

# When trying to run "yum updates" or "yum install" the "system is not registered with an entitlement server" error message is given
# To fix this issue:
RUN echo $'[main]\n\
enabled=0\n\\n\
# When following option is set to 1, then all repositories defined outside redhat.repo will be disabled\n\
# every time subscription-manager plugin is triggered by dnf or yum\n\
disable_system_repos=0\n'\
>> /etc/yum/pluginconf.d/subscription-manager.conf

# Reduce the number of layers in image by minimizing the number of separate RUN commands
# 1 - Install GCC, Git, Python 3.9, libraries needed for Python development, and pcre needed by uwsgi
# 2 - Set default Python version for `python` command, `python3` already points to the newly installed Python3.9
# 3 - Upgrade pip, after upgrading, both pip and pip3 are the same version
# 4 - Pip install wheel and uwsgi packages. Pip uses wheel to install uwsgi
# 5 - Clean all yum cache

RUN yum update -y && \
    yum install -y yum-utils && \
    yum install -y gcc git python python-devel && \
    python -m ensurepip --upgrade && \
    pip install wheel uwsgi && \
    yum clean all 

# Install su-exec for de-elevating root to deepphe user
# N.B. git and gcc are also needed for su-exec installation, but since already
#      added for uwsgi, they are simply used and are not removed like compilation-only packages.
WORKDIR /tmp
RUN yum install --assumeyes  procps-ng make && \
    git clone https://github.com/ncopa/su-exec.git /tmp/su-exec && \
    cd su-exec && \
    make && \
    mv su-exec /usr/local/bin/ && \
    chmod a+x /usr/local/bin/su-exec && \
    cd /tmp && \
    rm -Rf /tmp/su-exec/ && \
    yum remove --assumeyes make && \
    yum clean all
