FROM ubuntu:14.04

MAINTAINER FND <fndemers@gmail.com>

ENV PROJECTNAME=SL4A

# Working Directory
ENV WORKDIRECTORY /home/ubuntu

# Access SSH login
ENV USERNAME=ubuntu
ENV PASSWORD=ubuntu

ENV SL4A_APK1=sl4a-r6.1.1-arm-debug.apk
ENV SL4A_APK2=Python3ForAndroid-debug.apk
ENV QPYTHON=qpython3-gp-1.0.3.apk
ENV ANDROID_TOOLS=repository/sdk-tools-linux-3859397.zip
ENV ANDROID_SDK=android-sdk_r24.3.3-linux.tgz
ENV ANDROID_STUDIO=studio/ide-zips/3.0.1.0/android-studio-ide-171.4443003-linux.zip
ENV PYTHON=python

RUN apt-get update

RUN apt-get install -y python-dev unzip vim-nox

# Install a basic SSH server
RUN apt install -y openssh-server
RUN sed -i 's|session    required     pam_loginuid.so|session    optional     pam_loginuid.so|g' /etc/pam.d/sshd
RUN mkdir -p /var/run/sshd
RUN /usr/bin/ssh-keygen -A

# Add user to the image
RUN adduser --quiet --disabled-password --shell /bin/bash --home /home/${USERNAME} --gecos "User" ${USERNAME}
# Set password for the jenkins user (you may want to alter this).
RUN echo "$USERNAME:$PASSWORD" | chpasswd

# Installation Java.
# Open JDK
#RUN apt-get install -qy --no-install-recommends python-dev default-jdk
# Oracle Java 8
RUN apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:webupd8team/java \
    && apt-get update
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 \
    select true | /usr/bin/debconf-set-selections
RUN apt-get install -y oracle-java8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle/

# Install Deps
RUN dpkg --add-architecture i386 && apt-get update \
    && apt-get install -y --force-yes expect wget \
    libc6-i386 lib32stdc++6 lib32gcc1 lib32ncurses5 lib32z1

# Install Android Studio
RUN cd /opt \
    && mkdir -p android-sdk-linux && cd android-sdk-linux \
    && wget --quiet --output-document=android-studio.zip \
        https://dl.google.com/dl/android/${ANDROID_STUDIO} \
    && unzip -o -q android-studio.zip && rm -f android-studio.zip

# Install Android SDK
RUN cd /opt && wget --quiet --output-document=android-sdk.tgz \
    http://dl.google.com/android/${ANDROID_SDK} \
    && tar xzf android-sdk.tgz && rm -f android-sdk.tgz \
    && chown -R root.root android-sdk-linux

# Setup environment
ENV ANDROID_HOME /opt/android-sdk-linux
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools/bin

# Install sdk elements
COPY tools /opt/tools
ENV PATH ${PATH}:/opt/tools
RUN ["/opt/tools/android-accept-licenses.sh", \
    "android update sdk --all --force --no-ui --filter platform-tools,tools,build-tools-23,build-tools-23.0.2,android-23,addon-google_apis_x86-google-23,extra-android-support,extra-android-m2repository,extra-google-m2repository,extra-google-google_play_services,sys-img-armeabi-v7a-android-23"]

# Unzip tools if not unzipped.
# Strange that it is not uncompressed.
RUN cd ${ANDROID_HOME} \
    && unzip -o -q ${ANDROID_HOME}/temp/tools_r25.2.5-linux.zip

# Unzip new Android tools
RUN cd ${ANDROID_HOME} \
    && wget --quiet --output-document=tools.zip \
        https://dl.google.com/android/${ANDROID_TOOLS} \
    && unzip -o -q tools.zip \
    && rm -f tools.zip

# Accept all Android licenses
#RUN /opt/android-sdk-linux/tools/bin/sdkmanager --update
RUN ["/opt/tools/android-accept-licenses2.sh", \
    "/opt/android-sdk-linux/tools/bin/sdkmanager --update"]

# Pour exécuter Android Studio
RUN apt-get install -y libxtst6

# Acces X11
RUN echo "X11Forwarding yes" >> /etc/ssh/ssh_config

RUN apt install -y xauth vim-gtk

# Fournir accès complet à Android (REVOIR)
RUN chown $USERNAME -R /opt

RUN apt-get install -y qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils

RUN adduser $USERNAME libvirtd

RUN apt-get install -y virt-manager

RUN apt install -y git

# Installation de https://github.com/kevinwallace/qemu-docker
# qui permet d'avoir accès à la virtualisation KVM.
RUN cd /root \
    && git clone https://github.com/kevinwallace/qemu-docker.git \
    && mv -f qemu-docker qemu \
    && chmod +x /root/qemu/*.sh \
    && echo "/root/qemu/kvm-mknod.sh" >> /root/cmd.sh \
    && echo "chown root:$USERNAME /dev/kvm" >> /root/cmd.sh \
	&& echo "/usr/sbin/kvm-ok" >> /root/cmd.sh \
    && chmod +x /root/cmd.sh

# Rendre exécutable /root/cmd.sh à partir du compte $USERNAME
RUN echo "$USERNAME ALL = (root) NOPASSWD: /root/cmd.sh" >> /etc/sudoers

# Exécuter /root/cmd.sh au moment de la connexion au compte $USERNAME
RUN echo "sudo /root/cmd.sh" >> ${WORKDIRECTORY}/.bash_profile

# Installation Python 3
RUN apt-get update
RUN apt install -y git python3 python3-pip python3-mock
# Mise à jour PIP
RUN pip3 install --upgrade pip
RUN pip3 install flake8
RUN pip3 install flake8-docstrings
RUN pip3 install pylint

# Fournir accès complet à Android (REVOIR)
RUN chown $USERNAME -R /opt

## Clean up when done
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Port publish access
EXPOSE 5037
EXPOSE 5554
EXPOSE 5555

# Standard SSH port
EXPOSE 22

RUN mkdir -p ${WORKDIRECTORY}

RUN cd ${WORKDIRECTORY} \
    && mkdir -p work \
    && chown -R $USERNAME work

# Go to workspace
WORKDIR ${WORKDIRECTORY}

ADD ${SL4A_APK1} ${WORKDIRECTORY}
ADD ${SL4A_APK2} ${WORKDIRECTORY}
ADD ${QPYTHON} ${WORKDIRECTORY}
ADD ${PYTHON} ${WORKDIRECTORY}

RUN cd ${WORKDIRECTORY} \
    && mv -f ${SL4A_APK1} sl4a.apk \
    && mv -f ${SL4A_APK2} python3_for_android.apk \
    && mv -f ${QPYTHON} qpython3.apk \
    && chown ${USERNAME} *.apk
    #&& chown -R ${USERNAME} ${PYTHON}

RUN echo "export PYTHONPATH=." >> ${WORKDIRECTORY}/.bash_profile

RUN git clone https://github.com/pyenv/pyenv.git ${WORKDIRECTORY}/.pyenv
RUN echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ${WORKDIRECTORY}/.bash_profile
RUN echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ${WORKDIRECTORY}/.bash_profile
RUN echo 'eval "$(pyenv init -)"' >> ${WORKDIRECTORY}/.bash_profile

RUN echo "export PS1=\"\\e[0;31m $PROJECTNAME\\e[m \$PS1\"" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "export ANDROID_HOME=\"/opt/android-sdk-linux\"" >> ${WORKDIRECTORY}/.bash_profile
RUN echo "export PATH=\"\${PATH}:\${ANDROID_HOME}/tools:\${ANDROID_HOME}/platform-tools:\${ANDROID_HOME}/tools/bin:/opt/android-sdk-linux/android-studio/bin\"" >> ${WORKDIRECTORY}/.bash_profile
RUN chown ${USERNAME} ${WORKDIRECTORY}/.bash_profile

RUN mkdir -p ${WORKDIRECTORY}/.android \
    && chown ${USERNAME} ${WORKDIRECTORY}/.android \
    && touch ${WORKDIRECTORY}/.android/repositories.cfg \
    && chown ${USERNAME} ${WORKDIRECTORY}/.android/repositories.cfg

# Start SSHD server...
CMD ["/usr/sbin/sshd", "-D"]

