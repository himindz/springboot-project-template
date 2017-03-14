FROM devimage:latest
MAINTAINER Ali Khan <alikhan@himindz.ie>


ARG USER_NAME="dev"
ARG FULL_NAME="Developer"
ARG USER_EMAIL="dev@example.com"
ARG PASSWORD_HASH
ARG PASSWORD="test"

RUN echo "USER NAME ${PASSWORD_HASH}"
USER root
RUN mkdir -p /usr/share/jenkins/ref/users/${USER_NAME} \
    && mv /usr/share/jenkins/ref/users/${JENKINS_USER}/config.xml /usr/share/jenkins/ref/users/${USER_NAME}/config.xml

RUN usermod -l ${USER_NAME} ${JENKINS_USER} \
    && usermod -d /home/${USER_NAME} -m ${USER_NAME} \
    && usermod -c "${FULL_NAME}" ${USER_NAME} \
    && echo "${USER_NAME}:$PASSWORD" | chpasswd
RUN echo "${USER_NAME}    ALL=NOPASSWD: ALL" >>/etc/sudoers

RUN xmlstarlet ed --inplace  --update '//fullName' --value "$FULL_NAME" /usr/share/jenkins/ref/users/${USER_NAME}/config.xml \
    && xmlstarlet ed --inplace  --update '//passwordHash' --value "$PASSWORD_HASH" /usr/share/jenkins/ref/users/${USER_NAME}/config.xml \
    && xmlstarlet ed --inplace  --update '//emailAddress' --value "$USER_EMAIL" /usr/share/jenkins/ref/users/${USER_NAME}/config.xml \
    && xmlstarlet ed --inplace  --update "//com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl[2]/username" --value "$USER_NAME" /usr/share/jenkins/ref/credentials.xml \
    && xmlstarlet ed --inplace  --update "//com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl[2]/password" --value "$PASSWORD" /usr/share/jenkins/ref/credentials.xml

ENV JENKINS_USER ${USER_NAME}
WORKDIR /home/${JENKINS_USER}
USER ${JENKINS_USER}
