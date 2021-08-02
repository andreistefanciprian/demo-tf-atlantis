FROM runatlantis/atlantis:v0.16.1

RUN apk add --no-cache openssl make

# install helm3
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
chmod 700 get_helm.sh && \
./get_helm.sh && \
helm plugin install https://github.com/databus23/helm-diff

# install kubectl
ENV KUBECTL_VERSION=v1.19.4
RUN curl -LO https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl && \
chmod 755 kubectl && \
mv kubectl /usr/local/bin/

# install helmfile
ENV HELMFILE_VERSION=v0.135.0
RUN curl -fsSL -o helmfile https://github.com/roboll/helmfile/releases/download/$HELMFILE_VERSION/helmfile_linux_amd64 && \
chmod 755 helmfile && \
mv helmfile  /usr/local/bin

COPY entrypoint.sh /entrypoint.sh
COPY repos.yaml /repos.yaml
COPY flags.yaml /flags.yaml
RUN chmod +x /entrypoint.sh
ENTRYPOINT /entrypoint.sh
