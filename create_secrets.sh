while IFS= read -r line; do
    # get vars
    KEY=`echo $line | cut -d'=' -f1`
    VALUE=`echo $line | cut -d'=' -f2`
    
    # gcloud secrets delete $KEY --quiet
    
    # create secret
    echo "Creating secret: $KEY"
    gcloud secrets create $KEY
    echo $VALUE | gcloud secrets versions add $KEY  --data-file=-

    # read secret
    echo "Reading secret: $KEY"
    gcloud secrets versions access latest --secret=$KEY
done < env_vars
