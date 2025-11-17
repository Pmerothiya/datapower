#!/bin/bash


# main work
source ../user-input
NAMESPACE=$(echo "$NAMESPACE" | xargs)
DOMAIN=$(echo "$DOMAIN" | xargs)
SERVICE=$(echo "$SERVICE" | xargs)
HELM_RELEASE=$(echo "$HELM_RELEASE" | xargs)
CONFIG_FILE=$(echo "$CONFIG_FILE" | xargs)
LOCAL_FILE=$(echo "$LOCAL_FILE" | xargs)

oc login --token="${OCP_TOKEN}" --server="${OCP_URL}":6443 --insecure-skip-tls-verify
if [ $? -ne 0 ]; then
    echo "Error: oc login failed"
    exit 1
fi
# Step 1: Set project context
oc project $NAMESPACE 
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to set project '$NAMESPACE'.Ensure it exists and you have access."
  exit 1
fi
echo "Set project to '$NAMESPACE'."

# Step 2: Conditionally create ConfigMap for config file
if [ -n "$CONFIG_FILE" ]; then
    echo "DEBUG: Checking config file: $CONFIG_FILE"
    if [ -f "$CONFIG_FILE" ]; then
        config_base=$(basename "$CONFIG_FILE" | sed 's/\.[^.]*$//')
        CONFIG_CM="${config_base}-${DOMAIN}"

        if oc get configmap "$CONFIG_CM" -n "$NAMESPACE" >/dev/null 2>&1; then
            oc create configmap "$CONFIG_CM" --from-file="$CONFIG_FILE" -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
            echo "ConfigMap '$CONFIG_CM' created again. Skipping adding in service."
            CONFIG_CM=""  # Reset so it won't be added to values.yaml
        else
            oc create configmap "$CONFIG_CM" --from-file="$CONFIG_FILE" -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
            echo "ConfigMap '$CONFIG_CM' created."
        fi
    else
        echo "Config file '$CONFIG_FILE' not found. Skipping."
    fi
fi
# Step 3: Conditionally create ConfigMap for local file
sanitize_name() {
    local name="$1"
    echo "${name//./-}"
}

LOCAL_CMS=()
if [ -n "$LOCAL_FILE" ] && [ -d "$LOCAL_FILE" ]; then
    if [[ "$LOCAL_FILE" == *:* ]]; then
        local_path="${LOCAL_FILE%%:*}"
        rel_path="${LOCAL_FILE#*:}"
    else
        local_path="$LOCAL_FILE"
        filename=$(basename "$LOCAL_FILE")
        rel_path="$filename"
    fi

    filename=$(basename "$local_path")
    sanitized_filename=$(sanitize_name "$filename" | sed 's/\.[^.]*$//')
    tar_name="${sanitized_filename}.tar.gz"
    cm_name="${sanitized_filename}-${NAMESPACE}-${DOMAIN}"

    # ✅ Check if ConfigMap already exists
    if oc get configmap "$cm_name" -n "$NAMESPACE" >/dev/null 2>&1; then
        temp_dir=$(mktemp -d)
        tar -czvf "${temp_dir}/${tar_name}" -C "$local_path" .
        tar -tzf "${temp_dir}/${tar_name}"

        oc create configmap "$cm_name" --from-file="${temp_dir}/${tar_name}" -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
        echo "ConfigMap '$cm_name' created/applied again for local file '$local_path' at local:///$rel_path.Skipping adding in service"        

        cm_name=""  # ✅ Reset so it won't be added to LOCAL_CMS or values.yaml
    else
        temp_dir=$(mktemp -d)
        tar -czvf "${temp_dir}/${tar_name}" -C "$local_path" .
        tar -tzf "${temp_dir}/${tar_name}"

        oc create configmap "$cm_name" --from-file="${temp_dir}/${tar_name}" -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
        echo "ConfigMap '$cm_name' created/applied for local file '$local_path' at local:///$rel_path."
        LOCAL_CMS+=("$cm_name")
        rm -rf "$temp_dir"
    fi
else
    echo "No valid local_file specified or file not found. Skipping local ConfigMap."
fi

# Step 4: Conditionally create secret for certificate and optionally key
IFS=',' read -r -a CERT_ARRAY <<< "$CERT_FILE"

FROM_FILES=""
for file in "${CERT_ARRAY[@]}"; do
    if [ -f "$file" ]; then
        FROM_FILES+=" --from-file=$(basename "$file")=$file"
    else
        echo "WARNING: File '$file' not found, skipping."
    fi
done

if [ -n "$FROM_FILES" ]; then
    CERT_SECRET_NAME="${DOMAIN}-${NAMESPACE}-secret"

    # ✅ Check if Secret already exists
    if oc get secret "$CERT_SECRET_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
        oc create secret generic "$CERT_SECRET_NAME" $FROM_FILES -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
        echo "Secret '$CERT_SECRET_NAME' created/applied again with files: ${CERT_ARRAY[*]}. skipping adding in service"    
        CERT_SECRET_NAME=""  # Reset so it won't be added to values.yaml
    else
        oc create secret generic "$CERT_SECRET_NAME" $FROM_FILES -n "$NAMESPACE" --dry-run=client -o yaml | oc apply -f -
        echo "Secret '$CERT_SECRET_NAME' created/applied with files: ${CERT_ARRAY[*]}."
    fi
else
    echo "No valid cert files found. Skipping secret creation."
fi
# Step 5: Generate values.yaml
cat > "${ENV}_values.yaml" <<EOL
datapowerService:
  name: ${SERVICE}
  namespace: ${NAMESPACE}
  domains:
    - name: ${DOMAIN}
$(if [ -n "$CERT_SECRET_NAME" ]; then
    echo "      certs:"
    echo "        - certType: usrcerts"
    echo "          secret: ${CERT_SECRET_NAME}"
fi)
      dpApp:
        config:
$(if [ -n "$CONFIG_CM" ]; then echo "          - ${CONFIG_CM}"; fi)
        local:
$(if [ ${#LOCAL_CMS[@]} -gt 0 ]; then
    for cm in "${LOCAL_CMS[@]}"; do
        echo "          - ${cm}"
    done
fi)
EOL
echo "Generated "$ENV"_values.yaml with DOMAIN='$DOMAIN' and ConfigMap(s) '$CONFIG_CM' and '${LOCAL_CMS[*]}'."
cat  "$ENV"_values.yaml
