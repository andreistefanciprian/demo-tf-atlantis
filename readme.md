## Description

This repo describes the Atlantis Setup for running in a GCP VM container.

## Architecture

![Atlantis Architecture image](atlantis_architecture.png?raw=true "Atlantis GCP Architecture")

* Atlantis uses server side repo config file, eg: repos.yaml. In this config we can specify the allowed git repos Atlantis will work with and the terraform workflows.
* On the application repository side we can also have an atlantis.yaml file where repo structure and custom terraform workflows can be defined. These workflows can optionally override the workflows configured in the atlantis [repos.yaml](https://github.com/andreistefanciprian/demo-tf-env/blob/master/atlantis.yaml).
* The server configuration can be done via flags, env vars or config file. In this setup we're using environment variables that start with ATLANTIS_ string and config file (flags.yaml). [More details about this](https://www.runatlantis.io/docs/server-configuration.html#environment-variables)
* Atlantis will be secured with HTTPS Load Balancer with IAP enabled (To be done).
* Terraform state is stored in GCP bucket.
* [Terraform runs from](https://github.com/andreistefanciprian/demo-tf-env)
* [Terraform sample code](https://github.com/andreistefanciprian/demo-tf-code)


## Build Atlantis VM container

```
# define vars
GCP_PROJECT=<GCP-PROJECT>
GCP_ZONE=europe-west2-c
GCP_REGION=europe-west2
ATLANTIS_HOST=atlantis.example.com

# create GCP Service Account to be used by Atlantis
gcloud iam service-accounts create atlantis --description="Used by Atlantis GCP VM" --display-name=atlantis
gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:atlantis@${GCP_PROJECT}.iam.gserviceaccount.com --role=roles/compute.admin
gcloud projects add-iam-policy-binding $GCP_PROJECT --member=serviceAccount:atlantis@${GCP_PROJECT}.iam.gserviceaccount.com --role=roles/storage.admin

# verify Service Account was created
gcloud iam service-accounts describe atlantis@${GCP_PROJECT}.iam.gserviceaccount.com

# build Atlantis docker image
gcloud builds submit --tag gcr.io/$GCP_PROJECT/atlantis .

# reserve public ip for Atlantis VM
gcloud compute addresses create atlantis-pub-ip --project=$GCP_PROJECT --region=$GCP_REGION --quiet
gcloud compute addresses list

# create DNS A record (eg: <ATLANTIS_HOST> A <RESERVED-PUBLIC-IP>)

# Create Atlantis Git credentials (https://www.runatlantis.io/docs/access-credentials.html#generating-an-access-token)
# start Atlantis with fake github username and token
gcloud compute instances create-with-container atlantis-vm \
--project=$GCP_PROJECT \
--zone=$GCP_ZONE \
--container-image gcr.io/${GCP_PROJECT}/atlantis \
--address=atlantis-pub-ip \
--service-account=atlantis@${GCP_PROJECT}.iam.gserviceaccount.com \
--tags=http-server,https-server,atlantis \
--machine-type=e2-micro \
--scopes storage-rw,compute-rw \
--container-env ATLANTIS_GH_USER=fake \
--container-env ATLANTIS_GH_TOKEN=fake \
--container-env ATLANTIS_ATLANTIS_URL="http://$ATLANTIS_HOST" \
--container-env ATLANTIS_REPO_ALLOWLIST="github.com/andreistefanciprian/*" \
--container-env ATLANTIS_PORT=80

# visit http://$ATLANTIS_HOST/github-app/setup and click on Setup to create the app on Github. You'll be redirected back to Atlantis
# A link to install your app, along with its secrets, will be shown on the screen. Record your app's credentials and install your app for your user/org by following said link.
# Create a file with the contents of the GitHub App Key, e.g. $HOME/atlantis-app-key.pem

# create secret with Github API secret key
gcloud secrets create GITHUB_APP_KEY_FILE
gcloud secrets versions add GITHUB_APP_KEY_FILE --data-file=$HOME/atlantis-app-key.pem

# have all environment variables in env_vars file and run script to create secrets in Secrets Manager
cat << EOF > env_vars
ATLANTIS_GH_APP_ID=01211345
ATLANTIS_GH_WEBHOOK_SECRET=0000012345672209876540000
ATLANTIS_ATLANTIS_URL=http://atlantis.example.com
EOF

bash create_secrets.sh

# read secrets
_GITHUB_APP_KEY_FILE=`gcloud secrets versions access latest --secret=GITHUB_APP_KEY_FILE`
_ATLANTIS_GH_APP_ID=`gcloud secrets versions access latest --secret=ATLANTIS_GH_APP_ID`
_ATLANTIS_GH_WEBHOOK_SECRET=`gcloud secrets versions access latest --secret=ATLANTIS_GH_WEBHOOK_SECRET`
_ATLANTIS_ATLANTIS_URL=`gcloud secrets versions access latest --secret=ATLANTIS_ATLANTIS_URL`

# delete Atlantis instance and rebuild it with the new flags
gcloud compute instances delete atlantis-vm --project=$GCP_PROJECT --zone=$GCP_ZONE --quiet
gcloud compute instances create-with-container atlantis-vm \
--project=$GCP_PROJECT \
--zone=$GCP_ZONE \
--container-image gcr.io/${GCP_PROJECT}/atlantis \
--address=atlantis-pub-ip \
--service-account=atlantis@${GCP_PROJECT}.iam.gserviceaccount.com \
--tags=http-server,https-server,atlantis \
--machine-type=e2-micro \
--scopes storage-rw,compute-rw \
--container-env ATLANTIS_CONFIG=/flags.yaml \
--container-env GITHUB_APP_KEY_FILE=$_GITHUB_APP_KEY_FILE \
--container-env ATLANTIS_GH_APP_ID=$_ATLANTIS_GH_APP_ID \
--container-env ATLANTIS_GH_WEBHOOK_SECRET=$_ATLANTIS_GH_WEBHOOK_SECRET \
--container-env ATLANTIS_ATLANTIS_URL=$_ATLANTIS_ATLANTIS_URL \
--container-env ATLANTIS_PORT=80
```

## Prepare terraform

```bash
# create terraform state bucket
gsutil mb gs://${GCP_PROJECT}-tfstate
```

## Change terraform code and see Atlantis at work

To be added.

## HTTPS and IAP Auth

There are two ways to go about this.

1. Run Atlantis with SSL flags. Have ssl flags in the flags.yaml file:
```
ssl-cert-file: /bundle.atlantis.example.com.crt
ssl-key-file: /atlantis.example.com.key
```
Certs can be made available at runtime, the same way we did for the github API key file.
Enable IAP for VM.

2. Have HTTPS Load Balancer in front of Atlantis with IAP enabled.

## Clean up

```
# delete Atlantis instance
gcloud compute instances delete atlantis-vm --project=$GCP_PROJECT --zone=$GCP_ZONE --quiet

# delete Atlantis Terraform Service Account 
gcloud iam service-accounts delete atlantis@${GCP_PROJECT}.iam.gserviceaccount.com --quiet

# delete atlantis.example.com record zone
```
